import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Area tombol melekat di bawah (`.foot`): putih, garis atas, aman dari gesture bar.
class OlFootBar extends StatelessWidget {
  const OlFootBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: c.line)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x400B1F2E),
            offset: Offset(0, -12),
            blurRadius: 24,
            spreadRadius: -20,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OlSpace.screen,
            14,
            OlSpace.screen,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, w) in children.indexed) ...[
                if (i > 0) const SizedBox(height: OlSpace.sm),
                w,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
