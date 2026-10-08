import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

/// Kotak centang (`.chk`): terisi hijau saat aktif, area sentuh 48dp.
class OlCheckbox extends StatelessWidget {
  const OlCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.strikeWhenChecked = false,
  });

  final String label;

  /// Coret label saat dicentang (checklist alat TR-09).
  final bool strikeWhenChecked;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Semantics(
      container: true,
      checked: value,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: OlSize.minTouch),
          child: Row(
            children: [
              AnimatedContainer(
                duration: OlMotion.of(context, OlMotion.fast),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? c.ok : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: value
                      ? null
                      : Border.all(color: const Color(0xFFB3C3D0), width: 2),
                ),
                child: value
                    ? const OlIcon(OlIcons.check, size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: context.olText.body.copyWith(
                    fontSize: 15,
                    color: strikeWhenChecked && value ? context.ol.muted : null,
                    decoration: strikeWhenChecked && value
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
