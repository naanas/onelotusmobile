import 'package:flutter/material.dart';

/// Segitiga "putar" putih — pustaka ikon One Lotus tidak punya ikon play (D.1), jadi digambar.
class OlPlayGlyph extends StatelessWidget {
  const OlPlayGlyph({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _PlayPainter(), size: Size.square(28));
}

class _PlayPainter extends CustomPainter {
  const _PlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = Path()
      ..moveTo(c.dx - 7, c.dy - 10)
      ..lineTo(c.dx + 11, c.dy)
      ..lineTo(c.dx - 7, c.dy + 10)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_PlayPainter old) => false;
}
