import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pola QR untuk slicing UI (intake KS-02, QRIS). Bukan kode QR sungguhan —
/// nanti diganti generator QR dari payload server.
class PseudoQr extends StatelessWidget {
  const PseudoQr({
    super.key,
    required this.seed,
    this.size = 220,
    this.faded = false,
    this.semanticLabel = 'Kode QR',
  });

  final int seed;
  final double size;
  final bool faded;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final rnd = Random(seed);
    const n = 9;
    bool finder(int r, int col) =>
        (r < 3 && col < 3) ||
        (r < 3 && col >= n - 3) ||
        (r >= n - 3 && col < 3);
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.073),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.line, width: 1.5),
        ),
        child: Opacity(
          opacity: faded ? 0.15 : 1,
          child: GridView.count(
            crossAxisCount: n,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < n * n; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: finder(i ~/ n, i % n) || rnd.nextBool()
                        ? c.fg
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
