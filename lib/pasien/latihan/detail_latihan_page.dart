import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// PS-07 Detail latihan: video, langkah, batas nyeri/peringatan, catatan untuk terapis, "Selesai hari ini".
class DetailLatihanPage extends ConsumerStatefulWidget {
  const DetailLatihanPage({super.key, required this.id});
  final String id;

  @override
  ConsumerState<DetailLatihanPage> createState() => _DetailLatihanPageState();
}

class _DetailLatihanPageState extends ConsumerState<DetailLatihanPage> {
  final _note = TextEditingController();
  bool _busy = false;

  Future<ProgramItemV> _load() async {
    for (final p in await ref.read(pasienAppApiProvider).programs()) {
      for (final it in p.items) {
        if (it.id == widget.id) return it;
      }
    }
    throw const AppError(ErrorCode.notFound);
  }

  Future<void> _done() async {
    setState(() => _busy = true);
    final note = _note.text.trim();
    final ok = await runApi(
      context,
      () => ref.read(pasienAppApiProvider).logExercise(widget.id, done: true, note: note.isEmpty ? null : note).then((_) => true),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok == null) return;
    HapticFeedback.lightImpact();
    context.feedback.success('Tercatat. Kerja bagus!');
    context.pop();
  }

  @override
  Widget build(BuildContext context) => OlAsync<ProgramItemV>(
    load: _load,
    builder: (context, it, _) {
      final c = context.ol;
      final t = context.olText;
      final e = it.exercise;
      return [
        Text(e.name, style: t.title),
        Text(it.dose, style: t.bodyStrong.copyWith(color: c.brand)),
        if (e.videoUrl != null)
          OlCard(
            child: Row(
              children: [
                OlIcon(OlIcons.eye, color: c.brand),
                const SizedBox(width: OlSpace.md),
                Expanded(child: Text('Video contoh gerakan', style: t.bodyStrong)),
                OlButton.text(
                  label: 'Salin tautan',
                  small: true,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: e.videoUrl!));
                    context.feedback.success('Tautan video disalin. Buka di browser.');
                  },
                ),
              ],
            ),
          ),
        if (e.steps.isNotEmpty) ...[
          const OlSectionHeader(title: 'Langkah'),
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, s) in e.steps.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: OlSpace.sm),
                    child: Text('${i + 1}. $s', style: t.body),
                  ),
              ],
            ),
          ),
        ],
        if (e.warnings != null && e.warnings!.isNotEmpty) OlBanner(message: e.warnings!, tone: OlBannerTone.warn),
        OlTextField(label: 'Catatan untuk terapis (opsional)', controller: _note, maxLines: 2),
        if (it.doneToday)
          OlBanner(message: 'Latihan ini sudah ditandai selesai hari ini.', tone: OlBannerTone.info)
        else
          OlButton(label: 'Selesai hari ini', icon: OlIcons.check, loading: _busy, onPressed: _done),
      ];
    },
  ).asPage(context, 'Latihan');
}
