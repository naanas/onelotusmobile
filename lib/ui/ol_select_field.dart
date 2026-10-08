import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'feedback/app_feedback.dart';
import 'ol_button.dart';
import 'ol_icon.dart';

/// Pilihan tunggal berbentuk field — membuka bottom sheet berisi opsi.
class OlSelectField<T> extends StatelessWidget {
  const OlSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.sheetTitle,
    this.label,
    this.isRequired = false,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final String sheetTitle;
  final String? label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (isRequired)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: c.crit),
                  ),
              ],
            ),
            style: t.fieldLabel,
          ),
          const SizedBox(height: 8),
        ],
        Semantics(
          container: true,
          button: true,
          label: '${label ?? sheetTitle}: ${options[value]}',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(OlRadius.input),
            onTap: () async {
              final picked = await context.feedback.sheet<T>(
                title: sheetTitle,
                actions: [
                  for (final e in options.entries)
                    SheetAction(
                      e.value,
                      e.key,
                      variant: e.key == value
                          ? OlButtonVariant.primary
                          : OlButtonVariant.secondary,
                    ),
                ],
              );
              if (picked != null) onChanged(picked);
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: OlSize.input),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(OlRadius.input),
                border: Border.all(color: c.line, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      options[value]!,
                      style: t.body.copyWith(fontSize: 15),
                    ),
                  ),
                  OlIcon(OlIcons.chevronDown, size: 18, color: c.muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
