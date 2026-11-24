import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

/// Isi halaman muncul berurutan: tiap blok memudar masuk sambil naik sedikit, berjeda tipis dari blok
/// sebelumnya yang muncul di frame yang sama (maks. 7 jeda, jadi daftar panjang tetap cepat).
/// Hanya sekali saat blok pertama kali tampil; blok yang sudah ada tidak beranimasi ulang.
class OlAppear extends StatefulWidget {
  const OlAppear({super.key, required this.child});
  final Widget child;

  /// Bungkus anak-anak daftar: kunci (posisi, jenis) → isi yang berganti jenis (mis. memuat → data)
  /// ikut muncul halus, isi sejenis yang diperbarui tidak berkedip.
  static List<Widget> wrap(List<Widget> children) => [
    for (final (i, w) in children.indexed) OlAppear(key: ValueKey((i, w.runtimeType, w.key)), child: w),
  ];

  @override
  State<OlAppear> createState() => _OlAppearState();
}

class _OlAppearState extends State<OlAppear> with SingleTickerProviderStateMixin {
  // Urutan blok yang dipasang di frame yang sama → jeda bertingkat.
  static int _batch = 0;
  static bool _resetScheduled = false;

  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: OlMotion.emphasized);
  bool _skip = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final slot = _batch++;
    if (!_resetScheduled) {
      _resetScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _batch = 0;
        _resetScheduled = false;
      });
    }
    if (slot == 0) {
      _c.forward();
    } else {
      _timer = Timer(Duration(milliseconds: 45 * slot.clamp(1, 7)), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OlMotion.reduced(context) && !_skip) {
      _skip = true;
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(offset: Offset(0, (1 - _t.value) * 18), child: child),
    ),
  );
}
