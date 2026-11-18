import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

/// Tombol "geser untuk konfirmasi" (aksi uang: bayar). Mencegah ketuk tak sengaja.
/// Geser lingkaran sampai ujung kanan (≥ 85%) → [onConfirmed]. Dilepas sebelum itu → kembali.
/// [loading] = sedang diproses (lingkaran diam di kanan + spinner). `onConfirmed == null` → nonaktif.
class OlSlideToConfirm extends StatefulWidget {
  const OlSlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.loading = false,
    this.icon = OlIcons.lock,
  });

  final String label;
  final VoidCallback? onConfirmed;
  final bool loading;
  final OlIconData icon;

  @override
  State<OlSlideToConfirm> createState() => _OlSlideToConfirmState();
}

class _OlSlideToConfirmState extends State<OlSlideToConfirm>
    with SingleTickerProviderStateMixin {
  static const _h = 56.0, _pad = 4.0;
  // Dibuat di initState (bukan `late` malas): dispose() tidak boleh membuat controller baru.
  late final AnimationController _back;

  @override
  void initState() {
    super.initState();
    _back = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() => setState(() => _dx = _from * (1 - _back.value)));
  }

  double _dx = 0, _from = 0;
  bool _armed = false;

  @override
  void didUpdateWidget(OlSlideToConfirm old) {
    super.didUpdateWidget(old);
    // Selesai diproses (gagal/batal) → lingkaran kembali ke kiri.
    if (old.loading && !widget.loading) _reset();
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _reset() {
    _from = _dx;
    _armed = false;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final enabled = widget.onConfirmed != null && !widget.loading;
    return LayoutBuilder(
      builder: (context, box) {
        final thumb = _h - _pad * 2;
        final max = box.maxWidth - thumb - _pad * 2;
        final dx = widget.loading ? max : _dx.clamp(0.0, max);
        final p = max <= 0 ? 0.0 : dx / max;
        return Semantics(
          button: true,
          enabled: enabled,
          label: widget.label,
          onTap: enabled ? widget.onConfirmed : null,
          child: Container(
            height: _h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_h / 2),
              color: enabled || widget.loading
                  ? c.brand
                  : c.brand.withValues(alpha: .35),
              boxShadow: enabled ? OlShadow.brandButton : null,
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Jejak terang di belakang lingkaran.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: dx + thumb + _pad * 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.brandDeep.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(_h / 2),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(left: thumb + _pad * 2, right: 16),
                    child: Center(
                      child: Opacity(
                        opacity: widget.loading ? 1 : (1 - p * 1.4).clamp(0.0, 1.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.loading ? 'Memproses pembayaran…' : widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.button.copyWith(color: Colors.white),
                              ),
                            ),
                            if (!widget.loading) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.keyboard_double_arrow_right_rounded,
                                size: 18,
                                color: Colors.white.withValues(alpha: .7),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _pad + dx,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: enabled ? (_) => _back.stop() : null,
                    onHorizontalDragUpdate: enabled
                        ? (d) => setState(() {
                            _dx = (_dx + d.delta.dx).clamp(0.0, max);
                            final armed = _dx >= max * .85;
                            if (armed && !_armed) HapticFeedback.mediumImpact();
                            _armed = armed;
                          })
                        : null,
                    onHorizontalDragEnd: enabled
                        ? (_) {
                            if (_armed) {
                              setState(() => _dx = max);
                              HapticFeedback.heavyImpact();
                              widget.onConfirmed!();
                              // Diproses di layar lain (tanpa `loading` di sini) → kembali ke kiri,
                              // agar siap dipakai lagi saat pengguna kembali.
                              Future.delayed(const Duration(milliseconds: 600), () {
                                if (mounted && !widget.loading) _reset();
                              });
                            } else {
                              _reset();
                            }
                          }
                        : null,
                    child: Container(
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: OlShadow.sh1,
                      ),
                      alignment: Alignment.center,
                      child: widget.loading
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: c.brand,
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: OlMotion.of(context, OlMotion.fast),
                              child: _armed
                                  ? OlIcon(OlIcons.check, key: const ValueKey(1), color: c.ok)
                                  : Icon(
                                      Icons.chevron_right_rounded,
                                      key: const ValueKey(0),
                                      size: 28,
                                      color: enabled ? c.brand : c.faint,
                                    ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
