import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// AppHeader (§4): konteks kecil (tanggal · cabang) + judul, aksi di kanan.
/// [hero] = header biru tua beranda (D.5) — kartu pertama menumpuk ke dalamnya.
class OlAppHeader extends StatelessWidget {
  const OlAppHeader({
    super.key,
    required this.title,
    this.context_,
    this.actions = const [],
    this.below,
    this.hero = false,
    this.leading,
  });

  final String title;

  /// Teks konteks di atas judul, mis. "Sel, 6 Okt · Klinik Pusat Malang".
  final String? context_;
  final List<Widget> actions;

  /// Widget di bawah aksi kanan (mis. SyncIndicator di header beranda).
  final Widget? below;
  final bool hero;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final fg = hero ? Colors.white : c.fg;
    final ctxColor = hero ? const Color(0xFFA9D8F2) : c.muted;
    final top = MediaQuery.paddingOf(context).top;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        OlSpace.screen,
        top + (hero ? 20 : 18),
        OlSpace.screen,
        hero ? 76 : 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: OlSpace.sm)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (context_ != null) ...[
                  Text(
                    context_!,
                    style: t.caption.copyWith(
                      color: ctxColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Semantics(
                  header: true,
                  child: Text(title, style: t.title.copyWith(color: fg)),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty || below != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (actions.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: actions),
                if (below != null) ...[const SizedBox(height: 4), below!],
              ],
            ),
        ],
      ),
    );

    if (!hero) return content;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(OlRadius.heroBottom),
      ),
      child: Container(
        color: c.brandDeep,
        child: Stack(
          children: [
            // Lingkaran dekoratif kanan atas (`.hd.hero::after`).
            Positioned(
              right: -60,
              top: -70,
              child: Transform.rotate(
                angle: -0.785,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    color: Color(0x2938BDF8),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(110),
                      topRight: Radius.circular(110),
                      bottomRight: Radius.circular(110),
                    ),
                  ),
                ),
              ),
            ),
            content,
          ],
        ),
      ),
    );
  }
}
