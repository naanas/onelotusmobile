import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Peta sederhana dengan pin (bukan peta sungguhan — slicing UI): lokasi cabang
/// (OW-17, dengan radius check-in), lokasi sesi (PS-10), alamat home visit (PS-19).
class OlPinMap extends StatelessWidget {
  const OlPinMap({
    super.key,
    required this.semanticLabel,
    this.height = 150,
    this.radiusMeters,
    this.pinColor,
  });

  final String semanticLabel;
  final double height;
  final int? radiusMeters;
  final Color? pinColor;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(OlRadius.card),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _PinMapPainter(
            bg: const Color(0xFFDCEAF3),
            road: Colors.white,
            ring: pinColor ?? context.ol.brand,
            radius: radiusMeters,
          ),
        ),
      ),
    ),
  );
}

class _PinMapPainter extends CustomPainter {
  const _PinMapPainter({
    required this.bg,
    required this.road,
    required this.ring,
    required this.radius,
  });

  final Color bg;
  final Color road;
  final Color ring;

  /// null = tanpa lingkar radius.
  final int? radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final roadPaint = Paint()
      ..color = road
      ..strokeWidth = 10;
    canvas.drawLine(
      Offset(0, size.height * 0.62),
      Offset(size.width, size.height * 0.45),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.45, 0),
      Offset(size.width * 0.49, size.height),
      roadPaint,
    );
    final center = Offset(size.width * 0.48, size.height * 0.53);
    if (radius != null) _ring(canvas, size, center);
    _pin(canvas, center);
  }

  void _ring(Canvas canvas, Size size, Offset center) {
    // Skala tampilan: 200 m ≈ 40 px, dibatasi agar tetap di dalam peta.
    final r = (radius! / 5).clamp(14.0, size.height * 0.48);
    canvas.drawCircle(center, r, Paint()..color = ring.withValues(alpha: 0.12));
    final dash = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const n = 36;
    for (var i = 0; i < n; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        i * 2 * math.pi / n,
        2 * math.pi / n,
        false,
        dash,
      );
    }
  }

  void _pin(Canvas canvas, Offset center) {
    final pin = Path()
      ..moveTo(center.dx, center.dy)
      ..cubicTo(
        center.dx - 18,
        center.dy - 16,
        center.dx - 12,
        center.dy - 34,
        center.dx,
        center.dy - 34,
      )
      ..cubicTo(
        center.dx + 12,
        center.dy - 34,
        center.dx + 18,
        center.dy - 16,
        center.dx,
        center.dy,
      );
    canvas.drawPath(pin, Paint()..color = ring);
    canvas.drawPath(
      pin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PinMapPainter old) => old.radius != radius;
}
