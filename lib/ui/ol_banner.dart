import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

enum OlBannerTone { info, warn, crit, ok }

/// Banner kondisi yang berlangsung lama (§12.2): full width, radius 16, ikon kiri, aksi kanan.
class OlBanner extends StatelessWidget {
  const OlBanner({
    super.key,
    required this.message,
    this.tone = OlBannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final OlBannerTone tone;
  final OlIconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final (Color bg, Color fg, OlIconData defIcon) = switch (tone) {
      OlBannerTone.info => (c.brandSoft, c.brandDeep, OlIcons.info),
      OlBannerTone.warn => (c.warnSoft, c.warn, OlIcons.alert),
      OlBannerTone.crit => (c.critSoft, c.crit, OlIcons.alert),
      OlBannerTone.ok => (c.okSoft, c.ok, OlIcons.checkCircle),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(OlRadius.banner),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: OlIcon(icon ?? defIcon, size: 20, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: context.olText.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: OlSpace.sm),
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 24),
                  child: Text(
                    actionLabel!,
                    style: context.olText.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: fg,
                      decoration: TextDecoration.underline,
                      decorationColor: fg,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
