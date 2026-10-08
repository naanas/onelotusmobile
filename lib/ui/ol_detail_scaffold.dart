import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_foot_bar.dart';
import 'ol_icon.dart';
import 'ol_icon_button.dart';

/// Kerangka layar turunan (di atas tab bar): tombol kembali/tutup, judul besar,
/// konteks kecil, aksi kanan, isi tergulir, dan tombol melekat di bawah (`.foot`).
class OlDetailScaffold extends StatelessWidget {
  const OlDetailScaffold({
    super.key,
    required this.title,
    required this.children,
    this.context_,
    this.below,
    this.titleTrailing,
    this.actions = const [],
    this.foot = const [],
    this.close = false,
    this.showBack = true,
    this.background,
    this.top,
    this.gap = OlSpace.gap,
  });

  final String title;

  /// Teks kecil di atas judul, mis. "Sel, 6 Okt · 09.00–09.48 · Dimas".
  final String? context_;

  /// Widget di bawah judul (mis. deretan tag status).
  final Widget? below;

  /// Widget di kanan judul (mis. timer sesi di TR-04).
  final Widget? titleTrailing;
  final List<Widget> actions;
  final List<Widget> children;
  final List<Widget> foot;

  /// true = ikon tutup (×) untuk layar form, false = kembali (‹).
  final bool close;

  /// false = tanpa tombol kembali/tutup (mis. akar tab, langkah masuk pasien).
  final bool showBack;

  /// Latar layar; null = `bg` tema. Layar masuk pasien memakai putih.
  final Color? background;

  /// Widget di atas konteks/judul (mis. progres langkah booking PS-08).
  final Widget? top;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OlStatusBar.dark,
      child: Scaffold(
        backgroundColor: background,
        // Foot di bottomNavigationBar agar toast mengambang di atas tombol (§12.2).
        // Saat keyboard terbuka, foot pindah ke body supaya tetap di atas keyboard.
        bottomNavigationBar: foot.isEmpty || keyboard
            ? null
            : OlFootBar(children: foot),
        body: SafeArea(
          bottom: foot.isEmpty,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    OlSpace.screen,
                    12,
                    OlSpace.screen,
                    28,
                  ),
                  children: [
                    if (showBack || actions.isNotEmpty)
                      Row(
                        children: [
                          if (!showBack)
                            const SizedBox(height: OlSize.minTouch)
                          else
                            close
                                ? OlIconButton(
                                    icon: OlIcons.close,
                                    semanticLabel: 'Tutup',
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                  )
                                : const OlBackButton(),
                          const Spacer(),
                          ...actions,
                        ],
                      ),
                    if (top != null) ...[
                      if (showBack || actions.isNotEmpty)
                        const SizedBox(height: 12),
                      top!,
                      const SizedBox(height: 14),
                    ] else
                      const SizedBox(height: 6),
                    if (context_ != null) ...[
                      Text(
                        context_!,
                        style: t.caption.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(title, style: t.title),
                          ),
                        ),
                        if (titleTrailing != null) ...[
                          const SizedBox(width: OlSpace.sm),
                          titleTrailing!,
                        ],
                      ],
                    ),
                    if (below != null) ...[const SizedBox(height: 10), below!],
                    const SizedBox(height: 18),
                    for (final (i, w) in children.indexed) ...[
                      if (i > 0) SizedBox(height: gap),
                      w,
                    ],
                  ],
                ),
              ),
              if (foot.isNotEmpty && keyboard) OlFootBar(children: foot),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dua tombol berdampingan di area `.foot` (mis. "Tandai tidak tersedia" · "Ajukan cuti").
class OlFootRow extends StatelessWidget {
  const OlFootRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, w) in children.indexed) ...[
        if (i > 0) const SizedBox(width: OlSpace.md),
        Expanded(child: w),
      ],
    ],
  );
}
