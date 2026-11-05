import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/api/billing_api.dart';
import '../../../data/models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';
import '../../kasir/billing_common.dart';

/// AttachmentRow (§4) rekam sesi: foto & rontgen, maks 10 file / 10 MB. File dikirim ke API dan
/// dienkripsi server sebelum disimpan; tampilan diunduh lewat API (login + hak akses), tidak ada URL publik.
/// Isi hanya di memori (Image.memory), tidak disimpan ke galeri/cache HP.
class LampiranSection extends ConsumerStatefulWidget {
  const LampiranSection({
    super.key,
    required this.sessionId,
    required this.initial,
  });

  final String sessionId;
  final List<Attachment> initial;

  @override
  ConsumerState<LampiranSection> createState() => _LampiranSectionState();
}

class _Item {
  _Item({
    required this.kind,
    this.id,
    this.bytes,
    this.mime,
    this.state = UploadState.uploaded,
  });
  final AttachmentKind kind;
  String? id;
  Uint8List? bytes;
  final String? mime;
  UploadState state;
}

class _LampiranSectionState extends ConsumerState<LampiranSection> {
  static const _max = 10;
  static const _maxBytes = 10 << 20;
  late final _items = [
    for (final a in widget.initial)
      if (a.kind != AttachmentKind.voice)
        _Item(kind: a.kind, id: a.id, state: a.uploadState),
  ];

  BillingApi get _api => ref.read(billingApiProvider);

  Future<void> _add(AttachmentKind kind) async {
    if (_items.length >= _max) {
      context.feedback.info('Maksimal $_max lampiran per sesi.');
      return;
    }
    final source = await context.feedback.sheet<ImageSource>(
      title: kind == AttachmentKind.xray ? 'Tambah rontgen' : 'Tambah foto',
      actions: const [
        SheetAction('Kamera', ImageSource.camera),
        SheetAction(
          'Galeri',
          ImageSource.gallery,
          variant: OlButtonVariant.secondary,
        ),
      ],
    );
    if (source == null || !mounted) return;
    final XFile? file;
    try {
      // Rontgen butuh detail: resolusi lebih tinggi dari foto biasa.
      file = await ImagePicker().pickImage(
        source: source,
        imageQuality: kind == AttachmentKind.xray ? 90 : 75,
        maxWidth: kind == AttachmentKind.xray ? 2400 : 1600,
      );
    } on PlatformException {
      if (mounted) {
        context.feedback.info(
          'Izinkan akses kamera/galeri untuk menambah lampiran.',
        );
      }
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxBytes) {
      context.feedback.info('Ukuran file maksimal 10 MB.');
      return;
    }
    final name = file.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : name.endsWith('.heic')
        ? 'image/heic'
        : 'image/jpeg';
    final item = _Item(
      kind: kind,
      bytes: bytes,
      mime: mime,
      state: UploadState.uploading,
    );
    setState(() => _items.add(item));
    await _upload(item);
  }

  Future<void> _upload(_Item item) async {
    setState(() => item.state = UploadState.uploading);
    final id = await runApi(
      context,
      () => _api.upload(
        ownerType: 'session',
        ownerId: widget.sessionId,
        kind: item.kind.name,
        mime: item.mime!,
        bytes: item.bytes!,
      ),
    );
    if (!mounted) return;
    setState(() {
      item.id = id ?? item.id;
      item.state = id == null ? UploadState.failed : UploadState.uploaded;
    });
    if (id != null) {
      context.feedback.success(
        item.kind == AttachmentKind.xray
            ? 'Rontgen tersimpan (terenkripsi).'
            : 'Foto tersimpan.',
      );
    }
  }

  Future<Uint8List?> _bytes(_Item item) async {
    if (item.bytes != null) return item.bytes;
    final b = await _api.attachment(item.id!);
    return item.bytes = b;
  }

  Future<void> _open(_Item item) async {
    if (item.state == UploadState.failed && item.bytes != null) {
      return _upload(item);
    }
    if (item.state != UploadState.uploaded || item.id == null) return;
    final bytes = await runApi(context, () => _bytes(item).then((b) => b!));
    if (bytes == null || !mounted) return;
    await context.feedback.sheet<void>(
      title: item.kind == AttachmentKind.xray ? 'Rontgen' : 'Foto',
      child: InteractiveViewer(
        maxScale: 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OlRadius.input),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ),
      actions: const [SheetAction('Tutup', null)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Lampiran'),
              TextSpan(
                text: ' ${_items.length}/$_max',
                style: t.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          style: t.fieldLabel,
        ),
        const SizedBox(height: 8),
        if (_items.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final i in _items)
                _Tile(item: i, load: () => _bytes(i), onTap: () => _open(i)),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OlButton.secondary(
                label: 'Foto',
                icon: OlIcons.camera,
                small: true,
                onPressed: () => _add(AttachmentKind.photo),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OlButton.secondary(
                label: 'Rontgen',
                icon: OlIcons.xray,
                small: true,
                onPressed: () => _add(AttachmentKind.xray),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            OlIcon(OlIcons.lock, size: 14, color: c.muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Terenkripsi. Rontgen hanya bisa dibuka peran yang berwenang.',
                style: t.caption.copyWith(color: c.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({required this.item, required this.load, required this.onTap});

  final _Item item;
  final Future<Uint8List?> Function() load;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  Future<Uint8List?>? _thumb;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final i = widget.item;
    final xray = i.kind == AttachmentKind.xray;
    if (i.state == UploadState.uploaded && i.id != null) {
      _thumb ??= widget.load().catchError((Object _) => null);
    }
    final Widget body = switch (i.state) {
      UploadState.uploading ||
      UploadState.pending when i.bytes != null => Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: .4,
            child: Image.memory(i.bytes!, fit: BoxFit.cover),
          ),
          const Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ],
      ),
      UploadState.failed => Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            i.bytes != null
                ? 'Gagal. Ketuk untuk coba lagi.'
                : 'Gagal diunggah',
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: c.crit),
          ),
        ),
      ),
      _ => FutureBuilder<Uint8List?>(
        future: _thumb,
        builder: (context, snap) => snap.data != null
            ? Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true)
            : Center(
                child: snap.connectionState == ConnectionState.done
                    ? OlIcon(
                        xray ? OlIcons.lock : OlIcons.camera,
                        color: c.muted,
                      )
                    : const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              ),
      ),
    };
    return Semantics(
      button: true,
      label:
          '${xray ? 'Rontgen, akses terbatas' : 'Foto'}${i.state == UploadState.failed ? ', gagal diunggah' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(OlRadius.input),
        onTap: widget.onTap,
        child: Container(
          width: 96,
          height: 96,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(OlRadius.input),
            border: Border.all(
              color: i.state == UploadState.failed ? c.crit : c.line,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              body,
              if (xray)
                const Positioned(
                  left: 4,
                  bottom: 4,
                  child: OlTag('Akses terbatas', tone: OlTagTone.warn),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
