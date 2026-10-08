import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

/// Satu hari di [OlDayStrip].
class OlDay {
  const OlDay(this.label, this.day, {this.closed = false, this.done = false});

  /// "Sel".
  final String label;
  final int day;

  /// Klinik tutup — tampil redup, tidak bisa dipilih.
  final bool closed;

  /// Hari yang sudah dituntaskan (mis. latihan) — hijau dengan centang.
  final bool done;
}

/// Deret 7 hari untuk memilih tanggal (KS-06, PS-06, PS-08, PS-11).
class OlDayStrip extends StatelessWidget {
  const OlDayStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelect,
    this.month = 'Okt',
  });

  final List<OlDay> days;
  final int selected;
  final ValueChanged<int> onSelect;
  final String month;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Row(
      children: [
        for (final (i, d) in days.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Builder(
              builder: (context) {
                final sel = d.day == selected;
                final (bg, top, bottom) = sel
                    ? (c.brandDeep, const Color(0xFFA9D8F2), Colors.white)
                    : d.done
                    ? (c.okSoft, c.ok, c.ok)
                    : d.closed
                    ? (c.surfaceAlt, c.faint, c.faint)
                    : (c.surface, c.muted, c.fg);
                return Semantics(
                  container: true,
                  button: !d.closed,
                  selected: sel,
                  label: [
                    '${d.label} ${d.day} $month',
                    if (d.closed) 'tutup',
                    if (d.done) 'selesai',
                  ].join(', '),
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: d.closed
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            onSelect(d.day);
                          },
                    child: AnimatedContainer(
                      duration: OlMotion.of(context, OlMotion.fast),
                      height: 64,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: d.closed || d.done ? null : OlShadow.sh1,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(d.label, style: t.caption.copyWith(color: top)),
                          if (d.done && !sel)
                            OlIcon(OlIcons.check, size: 18, color: bottom)
                          else
                            Text(
                              '${d.day}',
                              style: t.heading.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: bottom,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
