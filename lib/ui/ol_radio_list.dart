import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

class OlRadioOption<T> {
  const OlRadioOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
  });
  final T value;
  final String title;
  final String? subtitle;
  final OlIconData? icon;
}

/// Kartu berisi daftar pilihan tunggal (UM-08).
class OlRadioList<T> extends StatelessWidget {
  const OlRadioList({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<OlRadioOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(OlRadius.card),
        boxShadow: OlShadow.sh1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
      child: Column(
        children: [
          for (final (i, o) in options.indexed)
            Semantics(
              inMutuallyExclusiveGroup: true,
              checked: o.value == value,
              button: true,
              child: InkWell(
                onTap: onChanged == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onChanged!(o.value);
                      },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: i == options.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Row(
                    children: [
                      if (o.icon != null) ...[
                        OlIcon(
                          o.icon!,
                          color: o.value == value ? c.brand : c.muted,
                          weight: OlIconWeight.duotone,
                        ),
                        const SizedBox(width: OlSpace.lg),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.title,
                              style: t.bodyStrong.copyWith(fontSize: 15),
                            ),
                            if (o.subtitle != null)
                              Text(
                                o.subtitle!,
                                style: t.caption.copyWith(fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: OlSpace.sm),
                      _Radio(selected: o.value == value),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return AnimatedContainer(
      duration: OlMotion.of(context, OlMotion.fast),
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? c.brand : const Color(0xFF8A9AA8),
          width: selected ? 2 : 1.5,
        ),
      ),
      child: AnimatedContainer(
        duration: OlMotion.of(context, OlMotion.fast),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? c.brand : Colors.transparent,
        ),
      ),
    );
  }
}
