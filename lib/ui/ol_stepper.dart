import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

/// Satu langkah di [OlStepper].
class OlStep {
  const OlStep(this.label, this.icon);
  final String label;
  final OlIconData icon;
}

/// Stepper beranimasi: lingkaran ikon per langkah dihubungkan jalur yang "mengalir"
/// saat pindah langkah. Langkah selesai → centang, langkah aktif → lebih besar + denyut halus.
/// Ketuk langkah yang sudah terbuka (`i <= maxReachable`, bukan langkah aktif) → [onTap].
class OlStepper extends StatefulWidget {
  const OlStepper({
    super.key,
    required this.steps,
    required this.current,
    this.maxReachable,
    this.onTap,
  });

  final List<OlStep> steps;
  final int current;
  final int? maxReachable;
  final ValueChanged<int>? onTap;

  @override
  State<OlStepper> createState() => _OlStepperState();
}

class _OlStepperState extends State<OlStepper> with TickerProviderStateMixin {
  static const _node = 30.0, _active = 38.0, _track = 4.0;

  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late Animation<double> _progress = AlwaysStoppedAnimation(widget.current.toDouble());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OlMotion.reduced(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(OlStepper old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      _progress = Tween(begin: _progress.value, end: widget.current.toDouble())
          .chain(CurveTween(curve: Curves.easeInOutCubic))
          .animate(_flow);
      _flow
        ..duration = OlMotion.of(context, const Duration(milliseconds: 520))
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final n = widget.steps.length;
    final reach = widget.maxReachable ?? widget.current;
    return Semantics(
      label: 'Langkah ${widget.current + 1} dari $n: ${widget.steps[widget.current].label}',
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = box.maxWidth / n;
          final x0 = cell / 2, span = cell * (n - 1);
          return AnimatedBuilder(
            animation: Listenable.merge([_flow, _pulse]),
            builder: (context, _) {
              final p = _progress.value;
              return SizedBox(
                height: _active + 26,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Jalur dasar.
                    Positioned(
                      left: x0,
                      width: span,
                      top: _active / 2 - _track / 2,
                      height: _track,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.line,
                          borderRadius: BorderRadius.circular(_track),
                        ),
                      ),
                    ),
                    // Jalur terisi (gradasi) yang mengalir ke langkah aktif.
                    Positioned(
                      left: x0,
                      width: n <= 1 ? 0 : span * (p / (n - 1)).clamp(0.0, 1.0),
                      top: _active / 2 - _track / 2,
                      height: _track,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [c.brand, c.brandDeep]),
                          borderRadius: BorderRadius.circular(_track),
                        ),
                      ),
                    ),
                    for (var i = 0; i < n; i++)
                      Positioned(
                        left: cell * i,
                        width: cell,
                        top: 0,
                        bottom: 0,
                        child: _buildNode(context, i, p, reach, c, t),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNode(BuildContext context, int i, double p, int reach, OlColors c, OlText t) {
    final step = widget.steps[i];
    // 0..1: seberapa "tercapai" node ini oleh aliran jalur.
    final hit = (p - i + 1).clamp(0.0, 1.0);
    final reached = p >= i - .02;
    final isCurrent = i == widget.current;
    final done = i < widget.current && p >= i;
    // Membesar saat aliran tiba di langkah aktif.
    final grow = isCurrent ? Curves.easeOutBack.transform(hit) : 0.0;
    final size = _node + (_active - _node) * grow;
    final tappable = widget.onTap != null && !isCurrent && i <= reach;
    final fg = reached ? Colors.white : (i <= reach ? c.brand : c.faint);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tappable
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!(i);
            }
          : null,
      child: Column(
        children: [
          SizedBox.square(
            dimension: _active,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (isCurrent && !OlMotion.reduced(context))
                  _Halo(t: _pulse.value, size: size, color: c.brand),
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(c.surface, isCurrent ? c.brandDeep : c.brand, reached ? 1 : 0),
                    border: Border.all(
                      color: reached ? Colors.transparent : (i <= reach ? c.brand.withValues(alpha: .5) : c.line),
                      width: 1.6,
                    ),
                    boxShadow: isCurrent && reached
                        ? [BoxShadow(color: c.brand.withValues(alpha: .35), blurRadius: 12, offset: const Offset(0, 4))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: OlMotion.of(context, OlMotion.slow),
                    transitionBuilder: (child, a) => ScaleTransition(
                      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                      child: FadeTransition(opacity: a, child: child),
                    ),
                    child: done
                        ? Icon(Icons.check_rounded, key: const ValueKey('done'), size: 17, color: fg)
                        : OlIcon(
                            step.icon,
                            key: ValueKey(step.icon),
                            size: isCurrent ? 18 : 15,
                            color: fg,
                            weight: isCurrent ? OlIconWeight.duotone : OlIconWeight.regular,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: OlMotion.of(context),
            style: t.caption.copyWith(
              color: isCurrent ? c.brandDeep : (i < widget.current ? c.brand : c.faint),
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            ),
            child: Text(step.label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
          ),
        ],
      ),
    );
  }
}

/// Lingkaran denyut di belakang langkah aktif.
class _Halo extends StatelessWidget {
  const _Halo({required this.t, required this.size, required this.color});
  final double t, size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeOut.transform(t);
    return IgnorePointer(
      child: Container(
        width: size + 14 * e,
        height: size + 14 * e,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: .22 * (1 - e)),
        ),
      ),
    );
  }
}
