import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/billing_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'billing_common.dart';

/// Rontgen yang diunggah pasien lewat form booking web. Isi diunduh lewat API (didekripsi server, tiap buka
/// diaudit) dan hanya disimpan di memori. Tidak tampil apa-apa bila tidak ada file / peran tidak boleh melihat.
class IntakeXray extends ConsumerStatefulWidget {
  const IntakeXray.booking({super.key, required String bookingId}) : id = bookingId, session = false;
  const IntakeXray.session({super.key, required String sessionId}) : id = sessionId, session = true;

  final String id;
  final bool session;

  @override
  ConsumerState<IntakeXray> createState() => _IntakeXrayState();
}

class _IntakeXrayState extends ConsumerState<IntakeXray> {
  BillingApi get _api => ref.read(billingApiProvider);
  late final Future<List<IntakeFileV>> _files = (widget.session
          ? _api.sessionIntakeAttachments(widget.id)
          : _api.bookingAttachments(widget.id))
      .catchError((_) => <IntakeFileV>[]);
  final _bytes = <String, Future<Uint8List>>{};

  Future<Uint8List> _load(IntakeFileV f) => _bytes[f.id] ??= _api.attachment(f.id);

  Future<void> _open(IntakeFileV f) async {
    if (!f.isImage) {
      context.feedback.info('File ${f.mime == 'application/pdf' ? 'PDF' : 'HEIC'} belum bisa dibuka di aplikasi.');
      return;
    }
    final bytes = await runApi(context, () => _load(f));
    if (bytes == null || !mounted) return;
    await context.feedback.sheet<void>(
      title: 'Rontgen dari pasien',
      child: InteractiveViewer(
        maxScale: 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OlRadius.input),
          child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
        ),
      ),
      actions: const [SheetAction('Tutup', null)],
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<IntakeFileV>>(
    future: _files,
    builder: (context, snap) {
      final files = snap.data ?? const [];
      if (files.isEmpty) return const SizedBox.shrink();
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
                Text('Rontgen dari pasien (${files.length})', style: t.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                OlIcon(OlIcons.lock, color: c.muted, size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in files)
                  Semantics(
                    button: true,
                    label: 'Buka rontgen',
                    child: GestureDetector(
                      onTap: () => _open(f),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 72,
                          height: 72,
                          color: c.surfaceAlt,
                          child: f.isImage
                              ? FutureBuilder<Uint8List>(
                                  future: _load(f),
                                  builder: (context, s) => s.data != null
                                      ? Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true)
                                      : Center(child: OlIcon(OlIcons.xray, color: c.muted)),
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
              ],
            ),
          ],
        ),
      );
    },
  );
}
