import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Baris label + toggle di dalam kartu form (OW-09, OW-13, OW-16).
class OwToggleRow extends StatelessWidget {
  const OwToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.body.copyWith(fontSize: 15.5)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: t.body.copyWith(
                      fontSize: 13.5,
                      color: context.ol.muted,
                    ),
                  ),
              ],
            ),
          ),
          OlToggle(value: value, onChanged: onChanged, semanticLabel: label),
        ],
      ),
    );
  }
}

/// Bar kemajuan tipis bergradasi (pemakaian voucher, kuota).
class OwProgress extends StatelessWidget {
  const OwProgress({super.key, required this.value});

  /// 0..1
  final double value;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (_, box) => Container(
        height: 10,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: context.ol.surfaceAlt,
          borderRadius: BorderRadius.circular(OlRadius.pill),
        ),
        child: Container(
          width: box.maxWidth * value.clamp(0.0, 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(OlRadius.pill),
            gradient: const LinearGradient(
              colors: [Color(0xFF38BDF8), Color(0xFF0277B5)],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Kartu item katalog: judul (opsional mono) + tag status, deskripsi, harga & info kanan.
class OwCatalogCard extends StatelessWidget {
  const OwCatalogCard({
    super.key,
    required this.title,
    required this.detail,
    this.mono = false,
    this.price,
    this.meta,
    this.active = true,
    this.statusLabel,
    this.selected = false,
    this.onTap,
    this.extra,
  });

  final String title;
  final String detail;
  final bool mono;
  final String? price;
  final String? meta;
  final bool active;
  final String? statusLabel;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final status = statusLabel ?? (active ? 'Aktif' : 'Nonaktif');
    final card = OlCard(
      onTap: onTap,
      semanticLabel: [title, status, detail, ?price, ?meta].join(', '),
      child: Opacity(
        opacity: active ? 1 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: mono
                        ? t.mono.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          )
                        : t.heading.copyWith(fontSize: 17),
                  ),
                ),
                OlTag(status, tone: active ? OlTagTone.ok : OlTagTone.muted),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: t.body.copyWith(
                fontSize: 14.5,
                color: mono && active ? c.fg : c.muted,
              ),
            ),
            if (extra != null) ...[const SizedBox(height: 10), extra!],
            if (price != null || meta != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (price != null)
                    Text(
                      price!,
                      style: t.mono.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(width: OlSpace.md),
                  Expanded(
                    child: Text(
                      meta ?? '',
                      textAlign: TextAlign.right,
                      style: t.body.copyWith(fontSize: 14, color: c.muted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (!selected) return card;
    // Item yang sedang diedit: garis brand seperti kartu terpilih KS-12.
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(OlRadius.card),
        border: Border.all(color: c.brand, width: 2),
      ),
      child: card,
    );
  }
}
