import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tanda logo One Lotus: tetes dengan sudut runcing di bawah (UM-01, UM-04).
class OlLogoMark extends StatelessWidget {
  const OlLogoMark({
    super.key,
    this.size = 72,
    this.color = const Color(0xFF38BDF8),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      // Kotak diputar −45° butuh ruang diagonal.
      dimension: size * 1.2,
      child: Center(
        child: Transform.rotate(
          angle: -math.pi / 4,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(size / 2),
                topRight: Radius.circular(size / 2),
                bottomRight: Radius.circular(size / 2),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
