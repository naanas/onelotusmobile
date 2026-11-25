import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_app_header.dart';
import 'ol_appear.dart';
import 'ol_icon.dart';
import 'ol_refresh.dart';

/// Isi halaman tab: header ikut tergulir bersama konten, latar `bg` yang sama di semua tab.
/// Dengan [heroOverlap], konten pertama menumpuk 56dp ke dalam header hero (D.5).
///
/// Saat digulir, area status bar ditutup latar opak agar konten tidak tampak
/// menembus jam/ikon sistem; warna ikon status bar ikut menyesuaikan.
///
/// [pinnedHeader] (bagian pasien): header tidak ikut tergulir. Header biasa diam di atas
/// (garis tipis muncul saat konten lewat di bawahnya). Header hero tetap tergulir agar
/// tidak memakan layar, lalu diganti bar ringkas biru berisi judul + aksi yang melekat.
class OlPageBody extends StatefulWidget {
  const OlPageBody({
    super.key,
    required this.header,
    required this.children,
    this.heroOverlap = false,
    this.onRefresh,
    this.pinnedHeader = false,
    this.foot,
    this.controller,
    this.backToTop = false,
    this.floatingBelow,
  });

  /// Tombol ↑ "Ke atas" muncul di kanan bawah setelah digulir jauh (daftar panjang).
  final bool backToTop;

  /// Hanya header hero melekat: widget yang ikut turun di bawah bar ringkas saat hero tergulir keluar
  /// (mis. kolom cari Data Pasien), dengan animasi yang sama dengan bar.
  final Widget? floatingBelow;

  /// Area tombol melekat di bawah (mis. [OlFootBar] wizard booking); tidak ikut tergulir.
  final Widget? foot;

  /// Pengendali gulir dari luar (mis. kembali ke atas saat ganti langkah).
  final ScrollController? controller;

  final Widget header;

  /// Header melekat di atas saat digulir (lihat dokumentasi kelas).
  final bool pinnedHeader;
  final List<Widget> children;
  final bool heroOverlap;

  /// Muat ulang tambahan saat layar ditarik (selain [OlAsync] di dalamnya yang otomatis).
  final Future<void> Function()? onRefresh;

  static const overlap = 56.0;

  @override
  State<OlPageBody> createState() => _OlPageBodyState();
}

class _OlPageBodyState extends State<OlPageBody> {
  late final ScrollController _scroll = widget.controller ?? ScrollController();
  final _headerKey = GlobalKey();
  bool _scrolled = false;

  /// Tombol "Ke atas" tampil.
  bool _far = false;

  /// 0..1: seberapa jauh bar ringkas hero sudah muncul.
  double _compact = 0;

  /// Posisi gulir untuk efek header hero (lihat [OlHeroScroll]).
  final _offset = ValueNotifier<double>(0);

  static const _barHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _offset.dispose();
    if (widget.controller == null) _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.heroOverlap && _scroll.hasClients) _offset.value = _scroll.offset;
    if (widget.backToTop && _scroll.hasClients) {
      // Muncul setelah ±1,5 layar ke bawah; hilang lagi dekat atas.
      final far = _scroll.offset > MediaQuery.sizeOf(context).height * 1.5;
      if (far != _far) setState(() => _far = far);
    }
    final top = MediaQuery.paddingOf(context).top;
    if (widget.pinnedHeader && widget.heroOverlap) {
      final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
      final h = box?.size.height ?? 0;
      // Bar mulai muncul sedikit sebelum sisa hero setinggi bar; selesai 48dp kemudian (lebih halus).
      final start = h - OlPageBody.overlap - top - _barHeight - 24;
      final v = ((_scroll.offset - start) / 48).clamp(0.0, 1.0);
      if (v != _compact) setState(() => _compact = v);
      return;
    }
    if (widget.pinnedHeader) {
      final scrolled = _scroll.offset > 0;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
      return;
    }
    var threshold = 1.0;
    if (widget.heroOverlap) {
      // Hero biru menutupi status bar sampai kartu yang menumpuk naik ke sana.
      final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
      final h = box?.size.height ?? 0;
      threshold = (h - OlPageBody.overlap - top).clamp(1.0, double.infinity);
    }
    final scrolled = _scroll.offset > threshold;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  Future<void> _toTop() async {
    if (!_scroll.hasClients) return;
    if (OlMotion.reduced(context)) return _scroll.jumpTo(0);
    // Daftar sangat panjang: lompat dulu ke dekat atas lalu meluncur, supaya tidak lama.
    final h = MediaQuery.sizeOf(context).height;
    if (_scroll.offset > h * 4) _scroll.jumpTo(h * 1.2);
    await _scroll.animateTo(0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    // Struktur selalu sama (ada/tidaknya foot) agar state isi halaman tidak hilang
    // saat tombol bawah muncul, mis. setelah data dimuat.
    // Di dalam tab dengan bar bawah tembus pandang (Scaffold.extendBody): padding bawah = tinggi bar.
    final inset = MediaQuery.paddingOf(context).bottom;
    final foot = widget.foot == null
        ? null
        : Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: MediaQuery.removePadding(context: context, removeBottom: true, child: widget.foot!),
          );
    Widget page = _page(context);
    if (widget.backToTop) {
      page = Stack(
        children: [
          Positioned.fill(child: page),
          Positioned(
            right: OlSpace.screen,
            bottom: OlSpace.lg + (widget.foot == null ? inset : 0),
            child: _BackToTop(visible: _far, onTap: _toTop),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: page), ?foot],
    );
  }

  Widget _page(BuildContext context) {
    final c = context.ol;
    final top = MediaQuery.paddingOf(context).top;
    final pinnedPlain = widget.pinnedHeader && !widget.heroOverlap;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: OlSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, w) in OlAppear.wrap(widget.children).indexed) ...[
            if (i > 0) const SizedBox(height: OlSpace.gap),
            w,
          ],
        ],
      ),
    );

    final list = ListView(
      controller: _scroll,
      physics: olRefreshPhysics,
      padding: EdgeInsets.only(bottom: 24 + (widget.foot == null ? MediaQuery.paddingOf(context).bottom : 0)),
      children: [
        if (!pinnedPlain)
          KeyedSubtree(
            key: _headerKey,
            child: widget.heroOverlap ? OlHeroScroll(offset: _offset, child: widget.header) : widget.header,
          ),
        if (pinnedPlain) const SizedBox(height: OlSpace.xs),
        if (widget.heroOverlap)
          Transform.translate(
            offset: const Offset(0, -OlPageBody.overlap),
            child: content,
          )
        else
          content,
      ],
    );

    if (pinnedPlain) {
      return ColoredBox(
        color: c.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: OlMotion.of(context, OlMotion.fast),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(
                  bottom: BorderSide(
                    color: _scrolled
                        ? c.line.withValues(alpha: 0.8)
                        : c.line.withValues(alpha: 0),
                  ),
                ),
              ),
              child: widget.header,
            ),
            Expanded(
              child: OlRefreshable(onRefresh: widget.onRefresh, child: list),
            ),
          ],
        ),
      );
    }

    if (widget.pinnedHeader) {
      final h = widget.header;
      final title = h is OlAppHeader ? h.title : null;
      final actions = h is OlAppHeader ? h.actions : const <Widget>[];
      return ColoredBox(
        color: c.bg,
        child: Stack(
          children: [
            OlRefreshable(onRefresh: widget.onRefresh, child: list),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: _compact < 1,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: OlStatusBar.light,
                  // Turun dari atas sambil muncul; judul menyusul naik (lihat _CompactHeroBar).
                  child: Opacity(
                    opacity: Curves.easeOut.transform(_compact),
                    child: Transform.translate(
                      offset: Offset(0, -(1 - Curves.easeOutCubic.transform(_compact)) * (top + _barHeight) * .35),
                      child: _CompactHeroBar(
                        height: top + _barHeight,
                        topInset: top,
                        title: title,
                        actions: actions,
                        progress: OlMotion.reduced(context) ? 1 : _compact,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.floatingBelow != null)
              Positioned(
                top: top + _barHeight + OlSpace.sm,
                left: OlSpace.screen,
                right: OlSpace.screen,
                child: IgnorePointer(
                  ignoring: _compact < 1,
                  child: Opacity(
                    opacity: Curves.easeOut.transform(_compact),
                    child: Transform.translate(
                      // Menyusul bar: turun dari balik bar sambil muncul.
                      offset: Offset(0, -(1 - Curves.easeOutCubic.transform(_compact)) * 28),
                      child: widget.floatingBelow,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final body = ColoredBox(
      color: c.bg,
      child: Stack(
        children: [
          OlRefreshable(onRefresh: widget.onRefresh, child: list),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top,
            child: IgnorePointer(
              // Digambar paling atas → region ini yang dibaca sistem untuk warna ikon.
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: _scrolled ? OlStatusBar.dark : _headerStyle,
                child: AnimatedOpacity(
                  opacity: _scrolled ? 1 : 0,
                  duration: OlMotion.of(context, OlMotion.fast),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.bg,
                      border: Border(
                        bottom: BorderSide(
                          color: c.line.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return body;
  }

  SystemUiOverlayStyle get _headerStyle =>
      widget.heroOverlap ? OlStatusBar.light : OlStatusBar.dark;
}

/// Bar ringkas biru yang menggantikan hero setelah hero tergulir keluar.
/// [progress] 0..1: judul naik & muncul sedikit setelah bar, bayangan menebal.
class _CompactHeroBar extends StatelessWidget {
  const _CompactHeroBar({
    required this.height,
    required this.topInset,
    required this.title,
    required this.actions,
    this.progress = 1,
  });

  final double height, topInset, progress;
  final String? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final tp = const Interval(.35, 1, curve: Curves.easeOutCubic).transform(progress);
    final radius = BorderRadius.vertical(bottom: Radius.circular(18 * (1 - progress)));
    final g = OlHeroBackdrop.gradient(c);
    // Kaca biru: gradasi sedikit tembus + blur konten di bawahnya; bayangan menebal saat muncul.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1F2E).withValues(alpha: .20 * progress),
            blurRadius: 22 * progress,
            offset: Offset(0, 8 * progress),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: height,
            padding: EdgeInsets.fromLTRB(OlSpace.screen, topInset, OlSpace.sm, 0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: g.begin,
                end: g.end,
                stops: g.stops,
                colors: [for (final x in g.colors) x.withValues(alpha: .9)],
              ),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: .08 * progress))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: tp,
                    child: Transform.translate(
                      offset: Offset(0, (1 - tp) * 14),
                      child: Text(
                        title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.heading.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pil "↑ Ke atas": kaca gelap (blur latar) + bayangan rapat — muncul dengan pegas, ditekan sedikit mengecil.
class _BackToTop extends StatefulWidget {
  const _BackToTop({required this.visible, required this.onTap});
  final bool visible;
  final VoidCallback onTap;

  @override
  State<_BackToTop> createState() => _BackToTopState();
}

class _BackToTopState extends State<_BackToTop> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final reduced = OlMotion.reduced(context);
    final v = widget.visible;
    const radius = BorderRadius.all(Radius.circular(OlRadius.pill));
    return IgnorePointer(
      ignoring: !v,
      child: AnimatedSlide(
        offset: v ? Offset.zero : const Offset(0, .6),
        duration: reduced ? Duration.zero : const Duration(milliseconds: 300),
        curve: v ? Curves.easeOutBack : Curves.easeInCubic,
        child: AnimatedOpacity(
          opacity: v ? 1 : 0,
          duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
          child: AnimatedScale(
            scale: _down ? .94 : 1,
            duration: const Duration(milliseconds: 120),
            child: Semantics(
              button: true,
              label: 'Kembali ke atas',
              child: GestureDetector(
                onTapDown: (_) => setState(() => _down = true),
                onTapCancel: () => setState(() => _down = false),
                onTapUp: (_) => setState(() => _down = false),
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onTap();
                },
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(color: Color(0x1F0B1F2E), blurRadius: 3, offset: Offset(0, 1)),
                      BoxShadow(color: Color(0x2E0B1F2E), blurRadius: 18, offset: Offset(0, 8), spreadRadius: -6),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.only(left: 12, right: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1F2E).withValues(alpha: .78),
                          borderRadius: radius,
                          border: Border.all(color: Colors.white.withValues(alpha: .12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.rotate(
                              angle: 3.14159265,
                              child: const OlIcon(OlIcons.chevronDown, size: 18, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Ke atas',
                              style: t.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
