import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../demo_data.dart';
import 'latihan_page.dart';

/// PS-07 Detail latihan: video (bisa diunduh), langkah, batas nyeri,
/// catatan untuk terapis, "Selesai hari ini".
class DetailLatihanPage extends StatefulWidget {
  const DetailLatihanPage({super.key, required this.id});

  final String id;

  @override
  State<DetailLatihanPage> createState() => _DetailLatihanPageState();
}

class _DetailLatihanPageState extends State<DetailLatihanPage> {
  late final _e = exerciseById(widget.id);
  final _note = TextEditingController(
    text: 'Set kedua terasa ringan, set ketiga agak goyah.',
  );
  bool _downloaded = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _finish() {
    _e.doneAt ??= Fmt.time(DateTime.now());
    context.feedback.success(
      _note.text.trim().isEmpty
          ? '${_e.name} selesai hari ini.'
          : '${_e.name} selesai. Catatan dikirim ke terapis.',
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: _e.name,
      below: Text(
        '${_e.doseLong} · ${_e.when}',
        style: t.body.copyWith(color: c.muted),
      ),
      foot: [
        OlButton(
          label: _e.done ? 'Sudah selesai hari ini' : 'Selesai hari ini',
          onPressed: _e.done ? null : _finish,
        ),
      ],
      children: [
        Semantics(
          button: true,
          label: 'Putar video ${_e.name}, durasi ${_e.duration}',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => context.feedback.info(
              'Pemutar video tersedia setelah video diunggah klinik.',
            ),
            child: VideoThumb(height: 180, duration: _e.duration),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                _downloaded
                    ? 'Video tersimpan di HP · bisa ditonton tanpa internet'
                    : 'Video bisa diunduh untuk ditonton tanpa internet',
                style: t.body.copyWith(fontSize: 14, color: c.muted),
              ),
            ),
            if (!_downloaded)
              OlButton.text(
                label: 'Unduh',
                onPressed: () {
                  setState(() => _downloaded = true);
                  context.feedback.success('Video diunduh.');
                },
              ),
          ],
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Langkah', style: t.heading.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              for (final (i, s) in _e.steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${i + 1}. $s',
                    style: t.body.copyWith(fontSize: 14.5),
                  ),
                ),
            ],
          ),
        ),
        const OlBanner(
          tone: OlBannerTone.warn,
          icon: OlIcons.alert,
          message: 'Hentikan bila nyeri terasa di atas 4 dari 10.',
        ),
        OlTextField(
          label: 'Catatan untuk terapis',
          controller: _note,
          maxLines: 3,
          helper: '${_note.text.length}/300',
          inputFormatters: [LengthLimitingTextInputFormatter(300)],
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
