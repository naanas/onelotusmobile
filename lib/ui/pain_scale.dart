import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// PainScale (§4): 0–10, dua baris (sebelum & sesudah), angka besar `7 → 3` di atas.
class PainScale extends StatelessWidget {
  const PainScale({
    super.key,
    required this.before,
    required this.after,
    required this.onBefore,
    required this.onAfter,
  });

  final int? before;
  final int? after;
  final ValueChanged<int> onBefore;
  final ValueChanged<int> onAfter;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Skala nyeri',
                style: t.heading.copyWith(fontSize: 17),
              ),
            ),
            Semantics(
              label:
                  'Nyeri ${before ?? 'belum diisi'} menjadi ${after ?? 'belum diisi'}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Text(
                    '${before ?? '–'}',
                    style: t.display.copyWith(fontSize: 26),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('→', style: t.heading.copyWith(color: c.muted)),
                  ),
                  Text(
                    '${after ?? '–'}',
                    style: t.display.copyWith(fontSize: 26, color: c.brand),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('SEBELUM SESI', style: t.overline),
        const SizedBox(height: 8),
        _Row(value: before, kind: _Kind.before, onChanged: onBefore),
        const SizedBox(height: 14),
        Text('SESUDAH SESI', style: t.overline),
        const SizedBox(height: 8),
        _Row(value: after, kind: _Kind.after, onChanged: onAfter),
      ],
    );
  }
}

enum _Kind { before, after }

class _Row extends StatelessWidget {
  const _Row({
    required this.value,
    required this.kind,
    required this.onChanged,
  });

  final int? value;
  final _Kind kind;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Row(
      children: [
        for (var i = 0; i <= 10; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              container: true,
              button: true,
              inMutuallyExclusiveGroup: true,
              selected: value == i,
              label:
                  'Nyeri ${kind == _Kind.before ? 'sebelum' : 'sesudah'} sesi $i',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
                child: AnimatedContainer(
                  duration: OlMotion.of(context, OlMotion.fast),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: value == i
                        ? (kind == _Kind.before
                              ? const Color(0xFFFDE2C4)
                              : c.brand)
                        : c.surfaceAlt,
                    border: value == i && kind == _Kind.before
                        ? Border.all(color: const Color(0xFFF6B26B), width: 2)
                        : null,
                    boxShadow: value == i && kind == _Kind.after
                        ? const [
                            BoxShadow(
                              color: Color(0xCC0277B5),
                              offset: Offset(0, 6),
                              blurRadius: 12,
                              spreadRadius: -6,
                            ),
                          ]
                        : null,
                  ),
                  child: FittedBox(
                    child: Text(
                      '$i',
                      style: t.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: value == i
                            ? (kind == _Kind.before ? c.warn : Colors.white)
                            : c.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
