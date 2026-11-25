import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Daftar kartu yang beranimasi saat isinya berubah: item baru memudar masuk sambil membuka tempat,
/// item yang hilang (mis. formulir disetujui, pemeriksaan dihapus) memudar & menyusut lalu dibuang, sehingga
/// kartu di bawahnya bergeser halus — tidak "loncat". Tiap anak WAJIB punya [Key] unik (mis. ValueKey(id)).
///
/// Item yang ada sejak pertama tampil tidak beranimasi di sini (sudah ditangani [OlAppear] milik halaman).
/// Hormati "kurangi gerakan" → perubahan langsung tanpa animasi.
class OlAnimatedItems extends StatefulWidget {
  const OlAnimatedItems({super.key, required this.children, this.spacing = OlSpace.gap});

  final List<Widget> children;
  final double spacing;

  static const enter = Duration(milliseconds: 260);
  static const exit = Duration(milliseconds: 200);

  @override
  State<OlAnimatedItems> createState() => _OlAnimatedItemsState();
}

class _Entry {
  _Entry(this.key, this.child, this.c);
  final Key key;
  Widget child;
  final AnimationController c;
  bool removing = false;
}

class _OlAnimatedItemsState extends State<OlAnimatedItems> with TickerProviderStateMixin {
  List<_Entry> _entries = [];

  @override
  void initState() {
    super.initState();
    _entries = [for (final w in widget.children) _make(w, animate: false)];
  }

  _Entry _make(Widget w, {required bool animate}) {
    assert(w.key != null, 'OlAnimatedItems: setiap anak butuh Key unik');
    final c = AnimationController(
      vsync: this,
      duration: OlAnimatedItems.enter,
      reverseDuration: OlAnimatedItems.exit,
      value: animate ? 0 : 1,
    );
    if (animate) c.forward();
    return _Entry(w.key!, w, c);
  }

  bool get _reduced => OlMotion.reduced(context);

  @override
  void didUpdateWidget(OlAnimatedItems old) {
    super.didUpdateWidget(old);
    final oldByKey = {for (final e in _entries) e.key: e};
    final newKeys = {for (final w in widget.children) w.key};
    // Isi diganti total (pencarian / filter baru): yang lama langsung dibuang, hanya yang baru masuk —
    // dua daftar yang menyusut & membuka bersamaan terasa berat.
    if (_entries.isNotEmpty && !_entries.any((e) => newKeys.contains(e.key))) {
      for (final e in _entries) {
        e.c.dispose();
      }
      _entries = [for (final w in widget.children) _make(w, animate: !_reduced)];
      return;
    }
    final used = <Key>{};
    final out = <_Entry>[];
    var ni = 0;

    _Entry take(Widget w) {
      final e = oldByKey[w.key];
      used.add(w.key!);
      if (e == null) return _make(w, animate: !_reduced);
      e.child = w;
      if (e.removing) {
        e.removing = false;
        e.c.forward();
      }
      return e;
    }

    // Gabungkan urutan baru dengan item lama yang hilang (tetap di posisinya selama animasi keluar).
    for (final e in _entries) {
      if (newKeys.contains(e.key)) {
        if (used.contains(e.key)) continue;
        while (ni < widget.children.length) {
          final w = widget.children[ni++];
          out.add(take(w));
          if (w.key == e.key) break;
        }
      } else {
        out.add(e);
        if (!e.removing) {
          e.removing = true;
          if (_reduced) {
            e.c.value = 0;
          } else {
            e.c.reverse();
          }
        }
      }
    }
    while (ni < widget.children.length) {
      out.add(take(widget.children[ni++]));
    }
    _entries = out;
    _sweepLater();
  }

  /// Buang item yang selesai keluar.
  void _sweepLater() {
    for (final e in _entries.where((e) => e.removing)) {
      if (e.c.isDismissed) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sweep());
        return;
      }
      e.c.addStatusListener(_onStatus);
    }
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.dismissed) _sweep();
  }

  void _sweep() {
    if (!mounted) return;
    final gone = _entries.where((e) => e.removing && e.c.isDismissed).toList();
    if (gone.isEmpty) return;
    setState(() => _entries.removeWhere(gone.contains));
    for (final e in gone) {
      e.c.dispose();
    }
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, e) in _entries.indexed)
          KeyedSubtree(
            key: e.key,
            child: _AnimatedEntry(
              animation: e.c,
              removing: e.removing,
              // Jarak ikut menyusut bersama kartu.
              child: Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : widget.spacing),
                child: IgnorePointer(ignoring: e.removing, child: e.child),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedEntry extends StatelessWidget {
  const _AnimatedEntry({required this.animation, required this.removing, required this.child});
  final Animation<double> animation;
  final bool removing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = CurvedAnimation(parent: animation, curve: OlMotion.curve, reverseCurve: Curves.easeInCubic);
    // Keluar: pudar lebih dulu, baru tempatnya menutup. Masuk: tempat membuka, lalu isi muncul.
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0.4, 1, curve: Curves.easeIn),
    );
    return SizeTransition(
      sizeFactor: size,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: fade,
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (_, c) => Transform.scale(scale: removing ? 0.96 + 0.04 * animation.value : 1, child: c),
        ),
      ),
    );
  }
}
