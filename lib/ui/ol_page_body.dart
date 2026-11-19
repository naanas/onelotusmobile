import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_app_header.dart';
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
  });

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

  @override
  Widget build(BuildContext context) {
    // Struktur selalu sama (ada/tidaknya foot) agar state isi halaman tidak hilang
    // saat tombol bawah muncul, mis. setelah data dimuat.
    final foot = widget.foot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: _page(context)), ?foot],
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
          for (final (i, w) in widget.children.indexed) ...[
            if (i > 0) const SizedBox(height: OlSpace.gap),
            w,
          ],
        ],
      ),
    );

    final list = ListView(
      controller: _scroll,
      physics: olRefreshPhysics,
      padding: const EdgeInsets.only(bottom: 24),
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
    return Container(
      height: height,
      padding: EdgeInsets.fromLTRB(OlSpace.screen, topInset, OlSpace.sm, 0),
      decoration: BoxDecoration(
        gradient: OlHeroBackdrop.gradient(c),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18 * (1 - progress))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1F2E).withValues(alpha: .22 * progress),
            blurRadius: 18 * progress,
            offset: Offset(0, 6 * progress),
          ),
        ],
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
    );
  }
}
