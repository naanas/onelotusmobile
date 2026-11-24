import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Angka yang "berhitung" dari nilai sebelumnya (awal: 0) ke nilai baru — statistik terasa hidup.
/// [format] mengubah angka jadi teks (mis. `(n) => '$n pasien terdaftar'`).
class OlCountUp extends StatelessWidget {
  const OlCountUp(this.value, {super.key, this.style, this.format, this.textAlign});

  final int value;
  final TextStyle? style;
  final String Function(int n)? format;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final f = format ?? (n) => '$n';
    if (OlMotion.reduced(context)) return Text(f(value), style: style, textAlign: textAlign);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutExpo,
      builder: (_, v, _) => Text(f(v.round()), style: style, textAlign: textAlign),
    );
  }
}
