import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'klinik_api.dart';
import 'klinik_models.dart';
import 'widgets.dart';

/// Blokir screenshot / rekam layar (Android FLAG_SECURE) selama foto rontgen tampil.
abstract final class SecureScreen {
  static const _ch = MethodChannel('onelotus/secure');
  static int _depth = 0;

  static Future<void> enter() async {
    if (_depth++ == 0) await _set(true);
  }

  static Future<void> leave() async {
    if (_depth > 0 && --_depth == 0) await _set(false);
  }

  static Future<void> _set(bool on) async {
    try {
      await _ch.invokeMethod<void>('set', on);
    } on MissingPluginException {
      // iOS / tes: tidak ada kanal → abaikan.
    } on PlatformException {
      // abaikan
    }
  }
}

/// Unggahan yang sedang berjalan / gagal (staf).
class _Pending {
  _Pending(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
  String? error;
}

/// Foto rontgen/MRI pasien, ditampilkan langsung di aplikasi. Isi diunduh lewat API (login staf, didekripsi
/// server, tiap buka diaudit) dan hanya disimpan di memori — tidak ada link, tombol simpan, atau bagikan.
/// Selama ada foto di layar, screenshot diblokir.
///
/// [IntakeXray.pasien]: semua rontgen pasien + (bila [editable]) staf bisa menambah dari galeri/kamera seperti
/// pasien di form web, dan menghapus foto yang diunggah staf. [IntakeXray.booking]: rontgen satu kiriman formulir.
class IntakeXray extends ConsumerStatefulWidget {
  const IntakeXray.booking({super.key, required String bookingId})
    : id = bookingId,
      pasien = false,
      editable = false;

  const IntakeXray.pasien({super.key, required String pasienId, this.editable = false})
    : id = pasienId,
      pasien = true;

  final String id;
  final bool pasien;
  final bool editable;

  @override
  ConsumerState<IntakeXray> createState() => _IntakeXrayState();
}

class _IntakeXrayState extends ConsumerState<IntakeXray> {
  static const _max = 8 << 20;

  KlinikApi get _api => ref.read(klinikApiProvider);
  List<RontgenFile>? _files;
  final _pending = <_Pending>[];
  final _bytes = <String, Future<Uint8List>>{};
  bool _secured = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    if (_secured) SecureScreen.leave();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await (widget.pasien ? _api.rontgen(widget.id) : _api.rontgenBooking(widget.id));
      if (!mounted) return;
      setState(() => _files = list);
      if (list.isNotEmpty && !_secured) {
        _secured = true;
        SecureScreen.enter();
      }
    } catch (_) {
      if (mounted) setState(() => _files ??= const []);
    }
  }

  Future<Uint8List> _load(RontgenFile f) => _bytes[f.id] ??= _api.isiFile(f.id);

  Future<void> _pick(ImageSource source) async {
    final img = await ImagePicker().pickImage(source: source, maxWidth: 2400, maxHeight: 2400, imageQuality: 85);
    if (img == null || !mounted) return;
    final bytes = await img.readAsBytes();
    final name = img.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    final p = _Pending(bytes, mime);
    if (bytes.length > _max) p.error = 'Ukuran foto maksimal 8 MB.';
    setState(() => _pending.add(p));
    if (p.error == null) await _upload(p);
  }

  Future<void> _upload(_Pending p) async {
    setState(() => p.error = null);
    try {
      final f = await _api.unggahRontgen(widget.id, p.bytes, p.mime);
      if (!mounted) return;
      _bytes[f.id] = Future.value(p.bytes);
      setState(() {
        _pending.remove(p);
        _files = [f, ...?_files];
      });
      if (!_secured) {
        _secured = true;
        SecureScreen.enter();
      }
      context.feedback.success('Foto rontgen tersimpan.');
    } on AppError catch (e) {
      if (mounted) setState(() => p.error = e.fieldError('file') ?? 'Gagal diunggah. Ketuk untuk coba lagi.');
    } catch (_) {
      if (mounted) setState(() => p.error = 'Gagal diunggah. Ketuk untuk coba lagi.');
    }
  }

  Future<void> _hapus(RontgenFile f) async {
    final ok = await confirmHapus(
      context,
      title: 'Hapus foto rontgen?',
      message: 'Foto ini dihapus dari data pasien.',
    );
    if (!ok || !mounted) return;
    try {
      await _api.hapusRontgen(widget.id, f.id);
      if (!mounted) return;
      setState(() => _files = [for (final x in _files ?? const <RontgenFile>[]) if (x.id != f.id) x]);
      context.feedback.success('Foto rontgen dihapus.');
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    }
  }

  Future<void> _open(RontgenFile f) async {
    if (!f.isImage) {
      context.feedback.info('File ${f.mime == 'application/pdf' ? 'PDF' : 'HEIC'} belum bisa ditampilkan di aplikasi.');
      return;
    }
    final images = [for (final x in _files ?? const <RontgenFile>[]) if (x.isImage) x];
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _RontgenViewer(files: images, initial: f, load: _load),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final files = _files ?? const <RontgenFile>[];
    final loading = _files == null;
    if (!widget.editable && files.isEmpty) return const SizedBox.shrink();
    final c = context.ol;
    final t = context.olText;
    return Padding(
      padding: const EdgeInsets.only(top: OlSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OlIcon(OlIcons.xray, color: c.brand, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Foto rontgen / MRI${files.isEmpty ? '' : ' (${files.length})'}',
                  style: t.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              OlIcon(OlIcons.lock, color: c.muted, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in files) _thumb(context, f),
              for (final p in _pending) _pendingTile(context, p),
              if (widget.editable && !loading) ...[
                _AddTile(icon: OlIcons.upload, label: 'Galeri', onTap: () => _pick(ImageSource.gallery)),
                _AddTile(icon: OlIcons.camera, label: 'Kamera', onTap: () => _pick(ImageSource.camera)),
              ],
              if (loading)
                const SizedBox(
                  width: 84,
                  height: 84,
                  child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                ),
            ],
          ),
          if (widget.editable) ...[
            const SizedBox(height: 6),
            Text(
              _pending.any((p) => p.error != null)
                  ? 'Ada foto yang gagal diunggah. Ketuk fotonya untuk coba lagi.'
                  : 'Disimpan terenkripsi, hanya bisa dibuka staf One Lotus di aplikasi.',
              style: t.caption.copyWith(color: _pending.any((p) => p.error != null) ? c.crit : c.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _thumb(BuildContext context, RontgenFile f) {
    final c = context.ol;
    final t = context.olText;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label: 'Lihat foto rontgen',
            child: GestureDetector(
              onTap: () => _open(f),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: c.surfaceAlt,
                  child: f.isImage
                      ? FutureBuilder<Uint8List>(
                          future: _load(f),
                          builder: (context, s) => s.data != null
                              ? Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true)
                              : Center(
                                  child: s.hasError
                                      ? OlIcon(OlIcons.xray, color: c.muted)
                                      : const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OlIcon(OlIcons.attach, color: c.muted),
                            Text(f.mime == 'application/pdf' ? 'PDF' : 'HEIC', style: t.caption),
                          ],
                        ),
                ),
              ),
            ),
          ),
          if (f.sumber == 'staf')
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(OlRadius.pill)),
                child: Text('Staf', style: t.caption.copyWith(color: Colors.white, fontSize: 10)),
              ),
            ),
          if (widget.editable && f.bisaHapus)
            Positioned(
              right: 4,
              top: 4,
              child: Semantics(
                button: true,
                label: 'Hapus foto rontgen',
                child: GestureDetector(
                  onTap: () => _hapus(f),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const OlIcon(OlIcons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pendingTile(BuildContext context, _Pending p) {
    final failed = p.error != null;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: failed && p.bytes.length <= _max ? () => _upload(p) : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(p.bytes, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: failed ? 0.55 : 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: failed
                    ? const OlIcon(OlIcons.refresh, color: Colors.white)
                    : const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      ),
              ),
            ),
          ),
          if (failed)
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: () => setState(() => _pending.remove(p)),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const OlIcon(OlIcons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, required this.onTap});
  final OlIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Semantics(
      button: true,
      label: 'Tambah foto rontgen dari ${label.toLowerCase()}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.brand.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OlIcon(icon, color: c.brand),
              const SizedBox(height: 4),
              Text(label, style: t.caption.copyWith(color: c.brand, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Layar penuh: geser antar foto, cubit untuk zoom. Tanpa tombol simpan / bagikan; screenshot diblokir.
class _RontgenViewer extends StatefulWidget {
  const _RontgenViewer({required this.files, required this.initial, required this.load});
  final List<RontgenFile> files;
  final RontgenFile initial;
  final Future<Uint8List> Function(RontgenFile) load;

  @override
  State<_RontgenViewer> createState() => _RontgenViewerState();
}

class _RontgenViewerState extends State<_RontgenViewer> {
  late final _ctl = PageController(
    initialPage: widget.files.indexWhere((f) => f.id == widget.initial.id).clamp(0, widget.files.length - 1),
  );
  late int _page = _ctl.initialPage;

  @override
  void initState() {
    super.initState();
    SecureScreen.enter();
  }

  @override
  void dispose() {
    SecureScreen.leave();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.files.length;
    final f = widget.files[_page];
    final info = [
      f.sumber == 'staf' ? 'Diunggah ${f.pengirim ?? 'staf'}' : 'Dari pasien',
      if (f.dikirim != null) tgl(f.dikirim),
    ].join(' · ');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n > 1 ? 'Rontgen ${_page + 1} dari $n' : 'Rontgen'),
            Text(info, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _ctl,
        itemCount: n,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) => FutureBuilder<Uint8List>(
          future: widget.load(widget.files[i]),
          builder: (context, s) {
            if (s.data != null) {
              return InteractiveViewer(
                maxScale: 6,
                child: Center(child: Image.memory(s.data!, fit: BoxFit.contain, gaplessPlayback: true)),
              );
            }
            if (s.hasError) {
              return const Center(
                child: Text('Foto gagal dimuat. Coba lagi.', style: TextStyle(color: Colors.white70)),
              );
            }
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          },
        ),
      ),
    );
  }
}
