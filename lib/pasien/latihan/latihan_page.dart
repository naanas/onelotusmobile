import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../demo_data.dart';
import '../pasien_routes.dart';

/// PS-06 Program latihan (tab Latihan): kepatuhan minggu ini, latihan hari ini
/// dengan video & centang, pengingat harian.
class LatihanPage extends StatefulWidget {
  const LatihanPage({super.key});

  @override
  State<LatihanPage> createState() => _LatihanPageState();
}

class _LatihanPageState extends State<LatihanPage> {
  int _day = 6;
  bool _reminder = true;

  void _toggle(DemoExercise e) {
    setState(() => e.doneAt = e.done ? null : Fmt.time(DateTime.now()));
    if (e.done) context.feedback.success('${e.name} selesai. Hebat!');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final done = demoExercises.where((e) => e.done).length;
    final isToday = _day == 6;
    return OlPageBody(
      header: const OlAppHeader(
        title: 'Program ankle',
        context_: 'Dari terapis Dimas · 29 Sep–12 Okt',
      ),
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Minggu ini',
                      style: t.heading.copyWith(fontSize: 16),
                    ),
                  ),
                  Text(
                    'Kepatuhan 86%',
                    style: t.bodyStrong.copyWith(color: c.ok),
                  ),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              OlDayStrip(
                days: const [
                  OlDay('Sen', 5, done: true),
                  OlDay('Sel', 6),
                  OlDay('Rab', 7),
                  OlDay('Kam', 8),
                  OlDay('Jum', 9),
                  OlDay('Sab', 10),
                  OlDay('Min', 11),
                ],
                selected: _day,
                onSelect: (d) => setState(() => _day = d),
              ),
            ],
          ),
        ),
        OlOverline(
          isToday
              ? 'HARI INI · $done DARI ${demoExercises.length} SELESAI'
              : 'JADWAL LATIHAN',
        ),
        for (final e in demoExercises)
          _ExerciseCard(
            exercise: e,
            canCheck: isToday,
            onOpen: () async {
              await context.push(PRoutes.latihanDetail(e.id));
              if (mounted) setState(() {});
            },
            onToggle: () => _toggle(e),
          ),
        OlCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pengingat latihan', style: t.bodyStrong),
                    Text.rich(
                      TextSpan(
                        text: 'Setiap hari pukul ',
                        children: [
                          TextSpan(
                            text: '07.00',
                            style: t.mono.copyWith(color: c.muted),
                          ),
                        ],
                      ),
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              OlToggle(
                value: _reminder,
                semanticLabel: 'Pengingat latihan',
                onChanged: (v) => setState(() => _reminder = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.canCheck,
    required this.onOpen,
    required this.onToggle,
  });

  final DemoExercise exercise;
  final bool canCheck;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final e = exercise;
    return OlCard(
      padding: const EdgeInsets.all(10),
      onTap: onOpen,
      semanticLabel:
          '${e.name}, ${e.dose}, ${e.when}${e.done ? ', selesai ${e.doneAt}' : ''}',
      child: Row(
        children: [
          VideoThumb(size: 72),
          const SizedBox(width: OlSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: t.bodyStrong.copyWith(
                    fontSize: 16,
                    color: e.done ? c.muted : c.fg,
                    decoration: e.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  e.done
                      ? '${e.dose} · selesai ${e.doneAt}'
                      : '${e.dose} · ${e.when}',
                  style: t.body.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          if (canCheck)
            Semantics(
              container: true,
              checked: e.done,
              label: 'Tandai ${e.name} selesai',
              excludeSemantics: true,
              child: InkResponse(
                radius: 24,
                onTap: onToggle,
                child: SizedBox.square(
                  dimension: OlSize.minTouch,
                  child: Center(
                    child: AnimatedContainer(
                      duration: OlMotion.of(context, OlMotion.fast),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: e.done ? c.ok : c.surface,
                        borderRadius: BorderRadius.circular(7),
                        border: e.done
                            ? null
                            : Border.all(color: c.faint, width: 2),
                      ),
                      child: e.done
                          ? const OlIcon(
                              OlIcons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kotak video bergradasi dengan segitiga putar.
class VideoThumb extends StatelessWidget {
  const VideoThumb({super.key, this.size, this.height, this.duration});

  final double? size;
  final double? height;
  final String? duration;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Container(
      width: size,
      height: size ?? height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size == null ? 22 : 14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.brandDeep, c.brand],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (size == null)
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0x33FFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          const OlPlayGlyph(),
          if (duration != null)
            Positioned(
              right: 14,
              bottom: 12,
              child: Text(
                duration!,
                style: context.olText.mono.copyWith(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
