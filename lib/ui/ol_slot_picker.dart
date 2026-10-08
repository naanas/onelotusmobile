import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class OlSlot {
  const OlSlot(this.time, {this.unavailableLabel});

  /// "09.00".
  final String time;

  /// Diisi bila slot tidak bisa dipilih ("Penuh", "Istirahat") — tetap tampil (§4).
  final String? unavailableLabel;
  bool get available => unavailableLabel == null;
}

/// SlotPicker (§4): grid 3 kolom; slot penuh dinonaktifkan dengan label, bukan disembunyikan.
class OlSlotPicker extends StatelessWidget {
  const OlSlotPicker({
    super.key,
    required this.slots,
    required this.selected,
    required this.onSelect,
  });

  final List<OlSlot> slots;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 16) / 3;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in slots)
              SizedBox(
                width: w,
                child: Semantics(
                  container: true,
                  button: s.available,
                  enabled: s.available,
                  selected: selected == s.time,
                  label: s.available
                      ? 'Jam ${s.time}'
                      : 'Jam ${s.time}, ${s.unavailableLabel}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: s.available
                        ? () {
                            HapticFeedback.selectionClick();
                            onSelect(s.time);
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: OlMotion.of(context, OlMotion.fast),
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !s.available
                            ? c.surfaceAlt
                            : (selected == s.time ? c.brandDeep : c.surface),
                        borderRadius: BorderRadius.circular(13),
                        border: s.available && selected != s.time
                            ? Border.all(color: c.line, width: 1.5)
                            : null,
                        boxShadow: selected == s.time
                            ? const [
                                BoxShadow(
                                  color: Color(0xCC0B3B5C),
                                  offset: Offset(0, 10),
                                  blurRadius: 18,
                                  spreadRadius: -10,
                                ),
                              ]
                            : null,
                      ),
                      child: s.available
                          ? Text(
                              s.time,
                              style: t.mono.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: selected == s.time ? Colors.white : c.fg,
                              ),
                            )
                          : Text(
                              '${s.time}\n${s.unavailableLabel}',
                              textAlign: TextAlign.center,
                              style: t.caption.copyWith(
                                fontSize: 12,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A6B4),
                                decoration: TextDecoration.lineThrough,
                                decorationColor: const Color(0xFF94A6B4),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
