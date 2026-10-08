import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Garis langkah (`.step`): langkah selesai & aktif berwarna brand.
class OlStepProgress extends StatelessWidget {
  const OlStepProgress({super.key, required this.count, required this.current});

  final int count;

  /// Indeks langkah aktif (0-based).
  final int current;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Langkah ${current + 1} dari $count',
    child: ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: OlMotion.of(context),
                height: 5,
                decoration: BoxDecoration(
                  color: i <= current
                      ? context.ol.brand
                      : const Color(0xFFDDE6ED),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
