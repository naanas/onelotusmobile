import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Efek kaca buram yang ramah performa. Blur (BackdropFilter) dihitung ulang tiap frame saat konten di
/// bawahnya bergerak: ringan di iOS (Metal), tapi membuat scroll & gestur patah-patah di banyak HP Android.
/// Android → tanpa blur; pemanggil memakai warna latar yang lebih pekat ([OlFrosted.alpha]).
class OlFrosted extends StatelessWidget {
  const OlFrosted({super.key, required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  /// Blur aktif hanya di platform Apple.
  static bool get enabled =>
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

  /// Alpha latar: [glass] bila blur aktif, [solid] bila tidak (konten di bawah tidak boleh terlalu tembus).
  static double alpha(double glass, {double solid = .97}) => enabled ? glass : solid;

  @override
  Widget build(BuildContext context) => enabled
      ? BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        )
      : child;
}
