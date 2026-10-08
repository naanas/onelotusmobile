import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';
import '../demo_data.dart';

/// TR-02 Jadwal minggu & ketersediaan: grid jam × hari, tandai jam tidak tersedia, status cuti.
class JadwalMingguPage extends StatefulWidget {
  const JadwalMingguPage({super.key});

  @override
  State<JadwalMingguPage> createState() => _JadwalMingguPageState();
}

class _JadwalMingguPageState extends State<JadwalMingguPage> {
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  static const _todayCol = 1;
  late final _grid = [
    for (final r in demoWeekGrid) [...r],
  ];
  int _week = 0;
  bool _marking = false;

  String get _range {
    final start = 5 + _week * 7;
    final end = start + 5;
    return '$start–$end Okt';
  }

  void _tap(int row, int col) {
    final slot = _grid[row][col];
    if (!_marking) {
      final hour = (8 + row).toString().padLeft(2, '0');
      context.feedback.info(switch (slot) {
        DemoSlot.session => '${_days[col]} $hour.00 · sesi terjadwal',
        DemoSlot.homeVisit => '${_days[col]} $hour.00 · home visit',
        DemoSlot.unavailable => '${_days[col]} $hour.00 · tidak tersedia',
        DemoSlot.free => '${_days[col]} $hour.00 · kosong',
      });
      return;
    }
    if (slot == DemoSlot.session || slot == DemoSlot.homeVisit) {
      context.feedback.info(
        'Jam ini sudah ada sesi. Minta kasir memindahkan sesi dulu.',
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(
      () => _grid[row][col] = slot == DemoSlot.free
          ? DemoSlot.unavailable
          : DemoSlot.free,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: _week == 0 ? 'Jadwal minggu ini' : 'Jadwal minggu depan',
      actions: [
        OlIconButton(
          icon: OlIcons.back,
          semanticLabel: 'Minggu sebelumnya',
          onPressed: _week == 0 ? null : () => setState(() => _week--),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(_range, style: t.bodyStrong.copyWith(fontSize: 15)),
        ),
        OlIconButton(
          icon: OlIcons.chevronRight,
          semanticLabel: 'Minggu berikutnya',
          onPressed: _week == 1 ? null : () => setState(() => _week++),
        ),
      ],
      foot: [
        OlFootRow(
          children: [
            OlButton.secondary(
              label: _marking ? 'Selesai menandai' : 'Tandai tidak tersedia',
              onPressed: () {
                setState(() => _marking = !_marking);
                if (_marking) {
                  context.feedback.info(
                    'Ketuk jam kosong untuk menandai tidak tersedia.',
                  );
                }
              },
            ),
            OlButton(
              label: 'Ajukan cuti',
              onPressed: () => context.push(Routes.terapisAjukanCuti),
            ),
          ],
        ),
      ],
      children: [
        Wrap(
          spacing: OlSpace.sm,
          runSpacing: OlSpace.sm,
          children: [
            _Legend(color: c.brand, label: 'Sesi'),
            const _Legend(color: Color(0xFFF2B263), label: 'Home visit'),
            const _Legend(striped: true, label: 'Tidak tersedia'),
          ],
        ),
        OlCard(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 36),
                  for (final (i, d) in _days.indexed)
                    Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: t.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: i == _todayCol && _week == 0
                                ? c.brand
                                : c.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (final (r, row) in _grid.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          (8 + r).toString().padLeft(2, '0'),
                          style: t.mono.copyWith(color: c.muted),
                        ),
                      ),
                      for (final (col, slot) in row.indexed)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _Cell(
                              slot: _week == 0
                                  ? slot
                                  : (col + r).isEven
                                  ? DemoSlot.free
                                  : DemoSlot.session,
                              label: '${_days[col]} jam ${8 + r}',
                              onTap: () => _tap(r, col),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        OlCard(
          child: Row(
            children: [
              const OlTag('Menunggu', tone: OlTagTone.warn),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cuti 14–15 Okt', style: t.heading),
                    Text(
                      'Keperluan keluarga · 3 sesi terdampak',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, this.color, this.striped = false});
  final String label;
  final Color? color;
  final bool striped;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: context.ol.surface,
      borderRadius: BorderRadius.circular(OlRadius.pill),
      border: Border.all(color: context.ol.line, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 14,
          child: striped
              ? CustomPaint(painter: _StripePainter(radius: 4))
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(label, style: context.olText.body.copyWith(fontSize: 14.5)),
      ],
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.slot, required this.label, required this.onTap});
  final DemoSlot slot;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final radius = BorderRadius.circular(9);
    final status = switch (slot) {
      DemoSlot.session => 'sesi',
      DemoSlot.homeVisit => 'home visit',
      DemoSlot.unavailable => 'tidak tersedia',
      DemoSlot.free => 'kosong',
    };
    return Semantics(
      container: true,
      button: true,
      label: '$label, $status',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: OlMotion.of(context, OlMotion.fast),
          height: 34,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: switch (slot) {
              DemoSlot.session => c.brand,
              DemoSlot.homeVisit => const Color(0xFFF2B263),
              DemoSlot.unavailable => const Color(0xFFE3EBF2),
              DemoSlot.free => const Color(0xFFE9F1F8),
            },
          ),
          child: slot == DemoSlot.unavailable
              ? ClipRRect(
                  borderRadius: radius,
                  child: CustomPaint(painter: _StripePainter()),
                )
              : null,
        ),
      ),
    );
  }
}

/// Arsiran diagonal "tidak tersedia".
class _StripePainter extends CustomPainter {
  _StripePainter({this.radius = 0});
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    canvas.drawRect(rect, Paint()..color = const Color(0xFFE3EBF2));
    final p = Paint()
      ..color = const Color(0xFFB7C7D4)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
}
