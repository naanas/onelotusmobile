import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Sakelar (`.tgl`): 46×28, aktif = brand. Area sentuh 48dp.
class OlToggle extends StatelessWidget {
  const OlToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final duration = OlMotion.of(context, OlMotion.fast);
    return Semantics(
      container: true,
      toggled: value,
      enabled: onChanged != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              },
        child: SizedBox(
          width: 56,
          height: OlSize.minTouch,
          child: Center(
            child: AnimatedOpacity(
              duration: duration,
              opacity: onChanged == null ? 0.5 : 1,
              child: AnimatedContainer(
                duration: duration,
                curve: OlMotion.curve,
                width: 46,
                height: 28,
                padding: const EdgeInsets.all(3),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: value ? c.brand : const Color(0xFFCBD7E1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x330B1F2E),
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
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
