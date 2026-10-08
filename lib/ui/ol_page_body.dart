import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Isi halaman tab: header ikut tergulir bersama konten, latar `bg` yang sama di semua tab.
/// Dengan [heroOverlap], konten pertama menumpuk 56dp ke dalam header hero (D.5).
///
/// Saat digulir, area status bar ditutup latar opak agar konten tidak tampak
/// menembus jam/ikon sistem; warna ikon status bar ikut menyesuaikan.
class OlPageBody extends StatefulWidget {
  const OlPageBody({
    super.key,
    required this.header,
    required this.children,
    this.heroOverlap = false,
  });

  final Widget header;
  final List<Widget> children;
  final bool heroOverlap;

  static const overlap = 56.0;

  @override
  State<OlPageBody> createState() => _OlPageBodyState();
}

class _OlPageBodyState extends State<OlPageBody> {
  final _scroll = ScrollController();
  final _headerKey = GlobalKey();
  bool _scrolled = false;

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
    final top = MediaQuery.paddingOf(context).top;
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
    final c = context.ol;
    final top = MediaQuery.paddingOf(context).top;
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
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        KeyedSubtree(key: _headerKey, child: widget.header),
        if (widget.heroOverlap)
          Transform.translate(
            offset: const Offset(0, -OlPageBody.overlap),
            child: content,
          )
        else
          content,
      ],
    );

    final body = ColoredBox(
      color: c.bg,
      child: Stack(
        children: [
          list,
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
