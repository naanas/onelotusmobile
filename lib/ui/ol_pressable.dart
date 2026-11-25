import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Umpan balik sentuh modern: saat ditekan elemen sedikit mengecil, saat dilepas memantul kembali
/// (pegas), plus getar halus saat diketuk. Pengganti riak (ripple) Material lama.
/// Tanpa [onTap] → anak dikembalikan apa adanya.
class OlPressable extends StatefulWidget {
  const OlPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = .97,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Skala saat ditekan (kartu .97, tombol .96).
  final double scale;
  final bool haptic;

  @override
  State<OlPressable> createState() => _OlPressableState();
}

class _OlPressableState extends State<OlPressable> {
  bool _down = false;
  Offset? _start;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) return widget.child;
    final reduced = OlMotion.reduced(context);
    return Listener(
      // Listener (bukan GestureDetector) agar gulir di dalam daftar tetap jalan; tekan → mengecil segera.
      onPointerDown: (e) {
        _start = e.position;
        _set(true);
      },
      // Jari bergeser (menggulir) → batal mengecil.
      onPointerMove: (e) {
        if (_start != null && (e.position - _start!).distance > 8) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _down && !reduced ? widget.scale : 1,
          // Turun cepat, naik dengan pantulan kecil.
          duration: Duration(milliseconds: _down ? 90 : 260),
          curve: _down ? Curves.easeOutCubic : OlMotion.spring,
          child: widget.child,
        ),
      ),
    );
  }
}
