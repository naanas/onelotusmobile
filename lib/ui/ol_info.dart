import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Baris label–nilai (`.mrow`): label kiri muted, nilai kanan tebal.
class OlInfoRow extends StatelessWidget {
  const OlInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
    this.divider = false,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.body.copyWith(fontSize: 15, color: c.muted)),
          const SizedBox(width: OlSpace.lg),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueStyle ?? t.bodyStrong.copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Judul seksi dengan aksi teks di kanan (mis. "Riwayat sesi · Kirim latihan").
class OlSectionHeader extends StatelessWidget {
  const OlSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: t.heading.copyWith(fontSize: 17)),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.ol.brand,
                textStyle: t.button,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Label seksi huruf kapital (`.lbl`), mis. "HARI INI · SEL, 6 OKT".
class OlOverline extends StatelessWidget {
  const OlOverline(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(text.toUpperCase(), style: context.olText.overline),
  );
}
