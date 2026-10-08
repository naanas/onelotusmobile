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
    this.actions = const [],
    this.foot = const [],
    this.close = false,
    this.gap = OlSpace.gap,
  });

  final String title;

  /// Teks kecil di atas judul, mis. "Sel, 6 Okt · 09.00–09.48 · Dimas".
  final String? context_;

  /// Widget di bawah judul (mis. deretan tag status).
  final Widget? below;
  final List<Widget> actions;
  final List<Widget> children;
  final List<Widget> foot;

  /// true = ikon tutup (×) untuk layar form, false = kembali (‹).
  final bool close;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OlStatusBar.dark,
      child: Scaffold(
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
                    Row(
                      children: [
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
                    Semantics(header: true, child: Text(title, style: t.title)),
                    if (below != null) ...[const SizedBox(height: 10), below!],
                    const SizedBox(height: 18),
                    for (final (i, w) in children.indexed) ...[
                      if (i > 0) SizedBox(height: gap),
                      w,
                    ],
                  ],
                ),
              ),
              if (foot.isNotEmpty) OlFootBar(children: foot),
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
