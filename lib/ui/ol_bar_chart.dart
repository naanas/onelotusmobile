import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Satu batang di [OlBarChart].
class OlBar {
  const OlBar(
    this.label,
    this.value, {
    this.display,
    this.highlight = false,
    this.dim = false,
  });

  final String label;
  final double value;

  /// Angka di atas batang; default [value] dengan koma desimal.
  final String? display;

  /// Batang aktif (periode berjalan) — warna brandDeep.
  final bool highlight;

  /// Batang redup, mis. hari libur.
  final bool dim;
}

/// Grafik batang sederhana (OW-01, OW-04): angka di atas, label di bawah.
/// Pembaca layar mendapat ringkasan teks, bukan batang satu per satu (§9).
class OlBarChart extends StatelessWidget {
  const OlBarChart({
    super.key,
    required this.bars,
    required this.semanticLabel,
    this.height = 130,
    this.gap = 12,
  });

  final List<OlBar> bars;
  final String semanticLabel;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final max = bars.fold<double>(0, (m, b) => b.value > m ? b.value : m);
    String fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height + 52,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, b) in bars.indexed) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        b.display ?? fmt(b.value),
                        style: t.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: max == 0 ? 0 : b.value / max),
                      duration: OlMotion.of(context, OlMotion.slow),
                      curve: OlMotion.curve,
                      builder: (_, f, _) => Container(
                        height: (height * f).clamp(8, height),
                        decoration: BoxDecoration(
                          color: b.highlight
                              ? c.brandDeep
                              : b.dim
                              ? const Color(0xFFA9BBC9)
                              : const Color(0xFF9BCBE8),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                            bottom: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      b.label,
                      maxLines: 1,
                      style: t.body.copyWith(fontSize: 13, color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Batang horizontal berlabel (OW-01 "Sesi per terapis").
class OlMeterRow extends StatelessWidget {
  const OlMeterRow({
    super.key,
    required this.label,
    required this.value,
    required this.max,
  });

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final f = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(label, style: t.body.copyWith(fontSize: 15)),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, box) => Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(OlRadius.pill),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: box.maxWidth * f,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(OlRadius.pill),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF0277B5)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$value',
                textAlign: TextAlign.right,
                style: t.bodyStrong.copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
