import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

enum OlTagTone { brand, outline, fill, ok, warn, crit, muted, strike, gold }

/// Tag status berbentuk pil. Selalu teks + warna (status tidak boleh hanya warna, §9).
class OlTag extends StatelessWidget {
  const OlTag(this.label, {super.key, this.tone = OlTagTone.brand, this.icon});

  final String label;
  final OlTagTone tone;
  final OlIconData? icon;

  /// Salinan dengan label/warna lain (mis. label pendek di ruang sempit).
  OlTag withLabel(String label, [OlTagTone? tone]) =>
      OlTag(label, key: key, tone: tone ?? this.tone, icon: icon);

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final (Color bg, Color fg, Border? border) = switch (tone) {
      OlTagTone.brand => (c.brandSoft, c.brandDeep, null),
      OlTagTone.outline => (
        Colors.transparent,
        c.brandDeep,
        Border.all(color: const Color(0xFF9CCDEB), width: 1.5),
      ),
      OlTagTone.fill => (c.brand, Colors.white, null),
      OlTagTone.ok => (c.okSoft, c.ok, null),
      OlTagTone.warn => (c.warnSoft, c.warn, null),
      OlTagTone.crit => (c.critSoft, c.crit, null),
      OlTagTone.muted => (c.surfaceAlt, c.muted, null),
      OlTagTone.strike => (c.surfaceAlt, c.muted, null),
      OlTagTone.gold => (c.goldSoft, c.gold, null),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(OlRadius.pill),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            OlIcon(icon!, size: 14, color: fg, weight: OlIconWeight.duotone),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: context.olText.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: fg,
                decoration: tone == OlTagTone.strike
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
