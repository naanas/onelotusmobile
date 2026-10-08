import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Segmented control (`.seg`): latar abu, segmen aktif putih terangkat.
class OlSegmented<T> extends StatelessWidget {
  const OlSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6EDF3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final e in segments.entries) ...[
            if (e.key != segments.keys.first) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                selected: e.key == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (e.key == value) return;
                    HapticFeedback.selectionClick();
                    onChanged(e.key);
                  },
                  child: AnimatedContainer(
                    duration: OlMotion.of(context, OlMotion.fast),
                    curve: OlMotion.curve,
                    constraints: const BoxConstraints(minHeight: 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: e.key == value ? c.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: e.key == value
                          ? const [
                              BoxShadow(
                                color: Color(0x140B1F2E),
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                              BoxShadow(
                                color: Color(0x330B1F2E),
                                offset: Offset(0, 4),
                                blurRadius: 10,
                                spreadRadius: -6,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: t.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: e.key == value ? c.fg : c.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
