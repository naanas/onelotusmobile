import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

typedef _Visit = ({
  String date,
  String day,
  String title,
  String therapist,
  String minutes,
  int before,
  int after,
  String area,
  String treatment,
  String advice,
});

const _visits = <_Visit>[
  (
    date: '6 Okt',
    day: 'Selasa, 6 Okt',
    title: 'Masase cedera',
    therapist: 'Dimas',
    minutes: '48 mnt',
    before: 3,
    after: 2,
    area: 'Ankle kiri, betis kiri',
    treatment: 'Masase cedera, stretching',
    advice: 'Lanjutkan calf raise 3×12 pagi dan sore. Kontrol Kamis.',
  ),
  (
    date: '29 Sep',
    day: 'Selasa, 29 Sep',
    title: 'Masase + kinesio tape',
    therapist: 'Dimas',
    minutes: '52 mnt',
    before: 4,
    after: 3,
    area: 'Ankle kiri',
    treatment: 'Masase cedera, kinesio tape',
    advice: 'Tape dilepas setelah 3 hari. Mulai ankle alphabet.',
  ),
  (
    date: '22 Sep',
    day: 'Selasa, 22 Sep',
    title: 'Adjustment ankle',
    therapist: 'Fajar',
    minutes: '60 mnt',
    before: 5,
    after: 4,
    area: 'Ankle kiri',
    treatment: 'Adjustment, infrared',
    advice: 'Kompres hangat 15 menit malam hari.',
  ),
];

/// PS-12 Riwayat sesi versi pasien: area, nyeri, perawatan, saran —
/// tanpa catatan internal terapis (§5.13, §10).
class RiwayatSesiPage extends StatefulWidget {
  const RiwayatSesiPage({super.key});

  @override
  State<RiwayatSesiPage> createState() => _RiwayatSesiPageState();
}

class _RiwayatSesiPageState extends State<RiwayatSesiPage> {
  int _open = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final v = _visits[_open];
    final others = [
      for (final (i, x) in _visits.indexed)
        if (i != _open) (i, x),
    ];
    Widget label(String s) => Text(s, style: t.body.copyWith(color: c.muted));

    return OlDetailScaffold(
      title: 'Riwayat sesi',
      children: [
        AnimatedSwitcher(
          duration: OlMotion.of(context),
          child: OlCard(
            key: ValueKey(_open),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(v.day, style: t.heading)),
                    Text(
                      '${v.therapist} · ${v.minutes}',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
                const SizedBox(height: OlSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 130,
                      child: Semantics(
                        label: 'Area: ${v.area}',
                        image: true,
                        child: CustomPaint(painter: _MiniBody(c.brand)),
                      ),
                    ),
                    const SizedBox(width: OlSpace.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label('Nyeri'),
                          Semantics(
                            label: 'Nyeri ${v.before} menjadi ${v.after}',
                            excludeSemantics: true,
                            child: Row(
                              children: [
                                Text(
                                  '${v.before}',
                                  style: t.display.copyWith(fontSize: 26),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    '→',
                                    style: t.heading.copyWith(color: c.muted),
                                  ),
                                ),
                                Text(
                                  '${v.after}',
                                  style: t.display.copyWith(
                                    fontSize: 26,
                                    color: c.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          label('Area'),
                          Text(v.area, style: t.bodyStrong),
                          const SizedBox(height: 8),
                          label('Perawatan'),
                          Text(v.treatment, style: t.bodyStrong),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OlSpace.md),
                Container(
                  padding: const EdgeInsets.all(OlSpace.lg),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label('Saran terapis'),
                      const SizedBox(height: 2),
                      Text(v.advice, style: t.body.copyWith(fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (k, (i, x)) in others.indexed)
                OlListItem(
                  leading: SizedBox(
                    width: 52,
                    child: Text(x.date, style: t.mono.copyWith(fontSize: 13.5)),
                  ),
                  title: x.title,
                  subtitle: 'Nyeri ${x.before} → ${x.after} · ${x.therapist}',
                  showChevron: true,
                  divider: k < others.length - 1,
                  onTap: () => setState(() => _open = i),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Siluet tubuh mini dengan titik di ankle kiri.
class _MiniBody extends CustomPainter {
  const _MiniBody(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = const Color(0xFFE3EEF6);
    final line = Paint()
      ..color = const Color(0xFFA9BBC9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final head = Offset(w / 2, h * 0.09);
    canvas
      ..drawCircle(head, h * 0.08, fill)
      ..drawCircle(head, h * 0.08, line);
    final body = Path()
      ..moveTo(w * 0.3, h * 0.2)
      ..lineTo(w * 0.7, h * 0.2)
      ..lineTo(w * 0.8, h * 0.46)
      ..lineTo(w * 0.72, h * 0.47)
      ..lineTo(w * 0.66, h * 0.32)
      ..lineTo(w * 0.64, h * 0.97)
      ..lineTo(w * 0.53, h * 0.97)
      ..lineTo(w * 0.5, h * 0.6)
      ..lineTo(w * 0.47, h * 0.97)
      ..lineTo(w * 0.36, h * 0.97)
      ..lineTo(w * 0.34, h * 0.32)
      ..lineTo(w * 0.28, h * 0.47)
      ..lineTo(w * 0.2, h * 0.46)
      ..close();
    canvas
      ..drawPath(body, fill)
      ..drawPath(body, line)
      ..drawCircle(Offset(w * 0.6, h * 0.94), 5.5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_MiniBody old) => false;
}
