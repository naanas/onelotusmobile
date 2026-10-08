import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pratinjau peta rute home visit (`.map`) — ilustrasi, bukan peta sungguhan.
/// Navigasi nyata lewat tombol "Buka Maps" (deep link Google Maps/Waze).
class RouteMapPreview extends StatelessWidget {
  const RouteMapPreview({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Peta rute ke alamat pasien',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(OlRadius.card),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _MapPainter(
            route: context.ol.brand,
            pin: context.ol.crit,
            start: context.ol.brandDeep,
          ),
        ),
      ),
    ),
  );
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.route, required this.pin, required this.start});
  final Color route;
  final Color pin;
  final Color start;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFDCEAF2));
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12;
    canvas.drawLine(
      Offset(0, s.height * 0.27),
      Offset(s.width, s.height * 0.2),
      road,
    );
    canvas.drawLine(
      Offset(0, s.height * 0.73),
      Offset(s.width, s.height * 0.53),
      road,
    );
    canvas.drawLine(
      Offset(s.width * 0.34, 0),
      Offset(s.width * 0.42, s.height),
      road,
    );
    canvas.drawLine(
      Offset(s.width * 0.69, 0),
      Offset(s.width * 0.65, s.height),
      road,
    );

    final a = Offset(s.width * 0.11, s.height * 0.69);
    final b = Offset(s.width * 0.74, s.height * 0.3);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(
        s.width * 0.38,
        s.height * 0.62,
        s.width * 0.38,
        s.height * 0.25,
        s.width * 0.52,
        s.height * 0.27,
      )
      ..lineTo(b.dx, b.dy);
    final dash = Paint()
      ..color = route
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 14) {
        canvas.drawPath(m.extractPath(d, d + 8), dash);
      }
    }
    canvas.drawCircle(a, 8, Paint()..color = start);
    // Pin tujuan.
    final pinPaint = Paint()..color = pin;
    final top = Offset(b.dx + 8, b.dy - 26);
    final pinPath = Path()
      ..addOval(Rect.fromCircle(center: top, radius: 17))
      ..moveTo(top.dx - 13, top.dy + 10)
      ..lineTo(top.dx, top.dy + 30)
      ..lineTo(top.dx + 13, top.dy + 10)
      ..close();
    canvas.drawPath(pinPath, pinPaint);
    canvas.drawCircle(top, 7, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MapPainter old) => false;
}
