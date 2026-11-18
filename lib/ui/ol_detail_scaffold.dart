import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_foot_bar.dart';
import 'ol_icon.dart';
import 'ol_icon_button.dart';
import 'ol_refresh.dart';

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
    this.onRefresh,
    this.pinnedHeader = false,
    this.onBack,
  });

  /// Aksi tombol kembali (default: tutup layar). Mis. pembayaran → ke daftar booking.
  final VoidCallback? onBack;

  /// Bagian pasien: baris kembali/aksi melekat di atas; judul besar tergulir,
  /// lalu judul ringkas muncul di baris itu (gaya judul besar iOS).
  final bool pinnedHeader;

  /// Muat ulang tambahan saat layar ditarik (selain [OlAsync] di dalamnya yang otomatis).
  final Future<void> Function()? onRefresh;

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
    if (pinnedHeader) return _PinnedDetail(this);
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
                child: OlRefreshable(
                  onRefresh: onRefresh,
                  child: ListView(
                    physics: olRefreshPhysics,
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
                                  : OlBackButton(onPressed: onBack),
                            const SizedBox(width: OlSpace.sm),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: actions,
                                  ),
                                ),
                              ),
                            ),
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
                      if (below != null) ...[
                        const SizedBox(height: 10),
                        below!,
                      ],
                      const SizedBox(height: 18),
                      for (final (i, w) in children.indexed) ...[
                        if (i > 0) SizedBox(height: gap),
                        w,
                      ],
                    ],
                  ),
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

/// [OlDetailScaffold] dengan header melekat.
class _PinnedDetail extends StatefulWidget {
  const _PinnedDetail(this.w);
  final OlDetailScaffold w;

  @override
  State<_PinnedDetail> createState() => _PinnedDetailState();
}

class _PinnedDetailState extends State<_PinnedDetail> {
  final _scroll = ScrollController();
  final _titleKey = GlobalKey();
  bool _scrolled = false;
  bool _titleGone = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final box = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    // Judul besar dianggap hilang saat bagian bawahnya lewat di bawah bar.
    final titleBottom = box == null ? 0.0 : box.size.height;
    final scrolled = _scroll.offset > 0;
    final gone = box != null && _scroll.offset > titleBottom - 8;
    if (scrolled != _scrolled || gone != _titleGone) {
      setState(() {
        _scrolled = scrolled;
        _titleGone = gone;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.w;
    final c = context.ol;
    final t = context.olText;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final fast = OlMotion.of(context, OlMotion.fast);

    final bar = AnimatedContainer(
      duration: fast,
      height: OlSize.minTouch + 8,
      padding: const EdgeInsets.symmetric(horizontal: OlSpace.screen - 4),
      decoration: BoxDecoration(
        color: w.background ?? c.bg,
        border: Border(
          bottom: BorderSide(
            color: c.line.withValues(alpha: _scrolled ? 0.8 : 0),
          ),
        ),
      ),
      child: Row(
        children: [
          if (w.showBack)
            w.close
                ? OlIconButton(
                    icon: OlIcons.close,
                    semanticLabel: 'Tutup',
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : OlBackButton(onPressed: w.onBack)
          else
            const SizedBox(width: 4),
          const SizedBox(width: OlSpace.xs),
          Expanded(
            child: AnimatedOpacity(
              opacity: _titleGone ? 1 : 0,
              duration: fast,
              child: AnimatedSlide(
                offset: _titleGone ? Offset.zero : const Offset(0, .3),
                duration: fast,
                child: Text(
                  w.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.heading,
                ),
              ),
            ),
          ),
          if (w.actions.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: w.actions),
            ),
        ],
      ),
    );

    final heading = Column(
      key: _titleKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (w.top != null) ...[w.top!, const SizedBox(height: 14)],
        if (w.context_ != null) ...[
          Text(
            w.context_!,
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
                child: Text(w.title, style: t.title),
              ),
            ),
            if (w.titleTrailing != null) ...[
              const SizedBox(width: OlSpace.sm),
              w.titleTrailing!,
            ],
          ],
        ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OlStatusBar.dark,
      child: Scaffold(
        backgroundColor: w.background,
        bottomNavigationBar: w.foot.isEmpty || keyboard
            ? null
            : OlFootBar(children: w.foot),
        body: SafeArea(
          bottom: w.foot.isEmpty,
          child: Column(
            children: [
              bar,
              Expanded(
                child: OlRefreshable(
                  onRefresh: w.onRefresh,
                  child: ListView(
                    controller: _scroll,
                    physics: olRefreshPhysics,
                    padding: const EdgeInsets.fromLTRB(
                      OlSpace.screen,
                      4,
                      OlSpace.screen,
                      28,
                    ),
                    children: [
                      heading,
                      if (w.below != null) ...[
                        const SizedBox(height: 10),
                        w.below!,
                      ],
                      const SizedBox(height: 18),
                      for (final (i, child) in w.children.indexed) ...[
                        if (i > 0) SizedBox(height: w.gap),
                        child,
                      ],
                    ],
                  ),
                ),
              ),
              if (w.foot.isNotEmpty && keyboard) OlFootBar(children: w.foot),
            ],
          ),
        ),
      ),
    );
  }
}
