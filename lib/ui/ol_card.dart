import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum OlCardVariant {
  /// Kartu putih biasa, tanpa border, bayangan sh1.
  plain,

  /// Kartu "sedang berjalan" / hero: gradien brand, teks putih.
  now,

  /// Aksen emas — hemat, maks 1 per layar (UpsellCard, poin).
  gold,
}

class OlCard extends StatelessWidget {
  const OlCard({
    super.key,
    required this.child,
    this.variant = OlCardVariant.plain,
    this.padding = const EdgeInsets.all(OlSpace.lg),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final OlCardVariant variant;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final radius = BorderRadius.circular(OlRadius.card);
    final decoration = switch (variant) {
      OlCardVariant.plain => BoxDecoration(
        color: c.surface,
        borderRadius: radius,
        boxShadow: OlShadow.sh1,
      ),
      OlCardVariant.now => BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment(-0.5, -1),
          end: Alignment(0.5, 1),
          colors: [Color(0xFF0277B5), Color(0xFF0B4F7A)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xB30277B5),
            offset: Offset(0, 18),
            blurRadius: 36,
            spreadRadius: -18,
          ),
        ],
      ),
      OlCardVariant.gold => BoxDecoration(
        color: c.goldSoft,
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFF3D9AE)),
      ),
    };

    Widget content = Padding(padding: padding, child: child);
    if (variant == OlCardVariant.now) {
      // Teks & ikon di dalam kartu "now" otomatis putih.
      content = DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: content,
        ),
      );
    }

    return Semantics(
      container: true,
      label: semanticLabel,
      button: onTap != null,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(borderRadius: radius, onTap: onTap, child: content),
        ),
      ),
    );
  }
}
