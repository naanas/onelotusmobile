import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

/// Chip pilihan (TreatmentChips, filter, area tubuh). Terpilih = `brandDeep` teks putih (D.5).
class OlChip extends StatelessWidget {
  const OlChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemove,
    this.icon,
    this.small = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Bila diisi, tampil "×" dan chip bisa dihapus (mis. chip area tubuh).
  final VoidCallback? onRemove;
  final OlIconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final fg = selected ? Colors.white : c.fg;
    final radius = BorderRadius.circular(OlRadius.pill);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        // Area sentuh minimal 48dp walau chip tampak lebih pendek.
        constraints: const BoxConstraints(minHeight: OlSize.minTouch),
        child: Center(
          widthFactor: 1,
          child: AnimatedContainer(
            duration: OlMotion.of(context, OlMotion.fast),
            curve: OlMotion.curve,
            constraints: BoxConstraints(minHeight: small ? 32 : 38),
            decoration: BoxDecoration(
              color: selected ? c.brandDeep : c.surface,
              borderRadius: radius,
              border: selected ? null : Border.all(color: c.line, width: 1.5),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onTap!();
                      },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: small ? 12 : 15),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        OlIcon(
                          icon!,
                          size: 16,
                          color: fg,
                          weight: selected
                              ? OlIconWeight.fill
                              : OlIconWeight.regular,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: context.olText.body.copyWith(
                          fontSize: small ? 12.5 : 13,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      if (onRemove != null) ...[
                        const SizedBox(width: 4),
                        InkResponse(
                          onTap: onRemove,
                          radius: 16,
                          child: OlIcon(
                            OlIcons.close,
                            size: 14,
                            color: fg,
                            semanticLabel: 'Hapus $label',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
