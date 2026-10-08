import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

/// Kotak pilihan (PaymentMethodSelector §4): ikon + label (+ keterangan), terpilih = garis brand.
class OlOptionTile extends StatelessWidget {
  const OlOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final OlIconData icon;
  final String label;
  final String? subtitle;
  final bool selected;

  /// null = tidak tersedia (mis. "Tidak ada kuota") — tetap tampil dengan alasan (§4).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final disabled = onTap == null;
    final radius = BorderRadius.circular(18);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: !disabled,
      label: subtitle == null ? label : '$label, $subtitle',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: OlMotion.of(context, OlMotion.fast),
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? c.brand : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: c.brandSoft, spreadRadius: 4)]
              : OlShadow.sh1,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: disabled
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  OlIcon(
                    icon,
                    color: disabled ? c.faint : (selected ? c.brand : c.muted),
                    weight: selected
                        ? OlIconWeight.duotone
                        : OlIconWeight.regular,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: t.bodyStrong.copyWith(
                            fontSize: 15.5,
                            color: disabled ? c.muted : c.fg,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: t.caption.copyWith(fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid 2 kolom yang tinggi tiap barisnya mengikuti isi tertinggi (tidak terpotong
/// saat teks diperbesar, berbeda dengan GridView berasio tetap).
class OlTwoColumnGrid extends StatelessWidget {
  const OlTwoColumnGrid({
    super.key,
    required this.children,
    this.gap = OlSpace.md,
  });

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < children.length; i += 2) ...[
        if (i > 0) SizedBox(height: gap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              SizedBox(width: gap),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
