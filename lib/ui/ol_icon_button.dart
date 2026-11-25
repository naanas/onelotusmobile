import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';
import 'ol_pressable.dart';

/// Tombol ikon kotak (`.icb`): 42dp tampak, area sentuh 48dp. Badge angka opsional.
class OlIconButton extends StatelessWidget {
  const OlIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.badge,
    this.onHero = false,
  });

  final OlIconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final int? badge;

  /// Di atas header hero gelap: ikon putih, latar transparan.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final radius = BorderRadius.circular(14);
    return Semantics(
      container: true,
      button: true,
      label: badge != null && badge! > 0
          ? '$semanticLabel, $badge baru'
          : semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: OlSize.minTouch,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bayangan & warna di wadah luar; Material transparan di dalam.
              // (Bayangan lewat Ink di dalam Material tampil sebagai lingkaran abu.)
              OlPressable(
                scale: .9,
                onTap: onPressed,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: onHero
                        ? Colors.white.withValues(alpha: 0.1)
                        : c.surface,
                    borderRadius: radius,
                    boxShadow: onHero ? null : OlShadow.sh1,
                  ),
                  child: Center(
                    child: AnimatedOpacity(
                      duration: OlMotion.of(context, OlMotion.fast),
                      opacity: onPressed == null ? 0.35 : 1,
                      child: OlIcon(
                        icon,
                        size: 22,
                        color: onHero ? Colors.white : c.fg,
                      ),
                    ),
                  ),
                ),
              ),
              if (badge != null && badge! > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: _BadgePop(
                    value: badge!,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 19),
                      height: 19,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.crit,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: onHero ? c.brandDeep : c.bg,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: context.olText.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol kembali di kiri atas (UM-06, UM-08).
class OlBackButton extends StatelessWidget {
  const OlBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OlIconButton(
    icon: OlIcons.back,
    semanticLabel: 'Kembali',
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
  );
}

/// Badge memantul (pegas) saat pertama muncul dan setiap angkanya bertambah.
class _BadgePop extends StatefulWidget {
  const _BadgePop({required this.value, required this.child});
  final int value;
  final Widget child;

  @override
  State<_BadgePop> createState() => _BadgePopState();
}

class _BadgePopState extends State<_BadgePop>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: .4,
        end: 1.22,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.22,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 55,
    ),
  ]).animate(_c);

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void didUpdateWidget(_BadgePop old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value && !OlMotion.reduced(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OlMotion.reduced(context)
      ? widget.child
      : ScaleTransition(scale: _scale, child: widget.child);
}
