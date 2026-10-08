import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Grafik tren nyeri per sesi (§5.3): garis brand, sumbu 0–10 berlabel,
/// angka awal & akhir tertulis. Label semantik merangkum tren (§9).
class PainTrendChart extends StatelessWidget {
  const PainTrendChart({
    super.key,
    required this.values,
    required this.startLabel,
    required this.endLabel,
  });

  final List<int> values;
  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final summary = values.isEmpty
        ? 'Belum ada data nyeri'
        : 'Tren nyeri ${values.length} sesi, dari ${values.first} ke ${values.last}';
    return Semantics(
      label: summary,
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: _PainPainter(
                values: values,
                line: c.brand,
                grid: c.line,
                axis: t.mono.copyWith(fontSize: 11, color: c.muted),
                point: t.mono.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.fg,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 32),
              Text(startLabel, style: t.caption.copyWith(fontSize: 13)),
              const Spacer(),
              Text(endLabel, style: t.caption.copyWith(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PainPainter extends CustomPainter {
  _PainPainter({
    required this.values,
    required this.line,
    required this.grid,
    required this.axis,
    required this.point,
  });

  final List<int> values;
  final Color line;
  final Color grid;
  final TextStyle axis;
  final TextStyle point;

  static const _left = 32.0;
  static const _top = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - _top - 6;
    final w = size.width - _left - 8;
    double y(num v) => _top + h * (1 - v / 10);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in const [10, 7, 3, 0]) {
      canvas.drawLine(Offset(_left, y(v)), Offset(size.width, y(v)), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '$v', style: axis),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y(v) - tp.height / 2));
    }
    if (values.isEmpty) return;

    final step = values.length == 1 ? 0.0 : w / (values.length - 1);
    final pts = [
      for (final (i, v) in values.indexed)
        Offset(_left + 8 + i * step * (w - 16) / w, y(v)),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = line;
    for (final (i, p) in pts.indexed) {
      canvas.drawCircle(p, i == pts.length - 1 ? 7 : 5.5, dot);
    }
    for (final i in {0, values.length - 1}) {
      final tp = TextPainter(
        text: TextSpan(text: '${values[i]}', style: point),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(pts[i].dx - tp.width / 2, pts[i].dy - tp.height - 6),
      );
    }
  }

  @override
  bool shouldRepaint(_PainPainter old) =>
      old.values != values || old.line != line;
}
