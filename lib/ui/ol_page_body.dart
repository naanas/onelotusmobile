import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Isi halaman tab: header ikut tergulir bersama konten, latar `bg` yang sama di semua tab.
/// Dengan [heroOverlap], konten pertama menumpuk 56dp ke dalam header hero (D.5).
class OlPageBody extends StatelessWidget {
  const OlPageBody({
    super.key,
    required this.header,
    required this.children,
    this.heroOverlap = false,
  });

  final Widget header;
  final List<Widget> children;
  final bool heroOverlap;

  static const overlap = 56.0;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: OlSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, w) in children.indexed) ...[
            if (i > 0) const SizedBox(height: OlSpace.gap),
            w,
          ],
        ],
      ),
    );
    return ColoredBox(
      color: context.ol.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          header,
          if (heroOverlap)
            Transform.translate(
              offset: const Offset(0, -overlap),
              child: content,
            )
          else
            content,
        ],
      ),
    );
  }
}
