import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Pola gerak antar layar (§2.5: 150–250ms, easeOutCubic, hormati "kurangi gerakan").
abstract final class OlTransitions {
  /// Durasi pindah layar. Sedikit di atas 250ms agar slide tidak terasa patah di HP kelas menengah.
  static const page = Duration(milliseconds: 300);
  static const tab = Duration(milliseconds: 220);
}

/// Shared axis horizontal: layar baru masuk sedikit dari kanan sambil memudar,
/// layar lama bergeser sedikit ke kiri sambil memudar. Dipakai untuk push/pop biasa.
class OlPageTransitionsBuilder extends PageTransitionsBuilder {
  const OlPageTransitionsBuilder();

  @override
  Duration get transitionDuration => OlTransitions.page;

  @override
  Duration get reverseTransitionDuration => OlTransitions.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (OlMotion.reduced(context)) return child;
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class SharedAxisTransition extends StatelessWidget {
  const SharedAxisTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  static const _shift = 0.06; // fraksi lebar layar

  @override
  Widget build(BuildContext context) {
    // Masuk: 30% awal kosong (fade-through), lalu muncul.
    final inFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
    );
    final inSlide = Tween(begin: const Offset(_shift, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: animation,
            curve: OlMotion.curve,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    // Keluar (saat layar lain di-push di atasnya): memudar cepat & bergeser ke kiri.
    final outFade = ReverseAnimation(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0, 0.3, curve: Curves.easeIn),
      ),
    );
    final outSlide = Tween(begin: Offset.zero, end: const Offset(-_shift, 0))
        .animate(
          CurvedAnimation(parent: secondaryAnimation, curve: OlMotion.curve),
        );

    return ColoredBox(
      color: context.ol.bg,
      child: FadeTransition(
        opacity: outFade,
        child: SlideTransition(
          position: outSlide,
          child: FadeTransition(
            opacity: inFade,
            child: SlideTransition(position: inSlide, child: child),
          ),
        ),
      ),
    );
  }
}

/// Halaman go_router dengan fade — untuk pergantian fase (splash → login → beranda, kunci).
CustomTransitionPage<void> olFadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: OlTransitions.page,
      reverseTransitionDuration: OlTransitions.page,
      transitionsBuilder: (context, animation, secondary, child) {
        if (OlMotion.reduced(context)) return child;
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.985, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: OlMotion.curve),
            ),
            child: child,
          ),
        );
      },
    );

/// Wadah cabang StatefulShellRoute dengan fade-through antar tab:
/// tab lama memudar cepat, tab baru muncul sambil sedikit membesar (0.98 → 1).
/// State tiap tab tetap hidup (seperti IndexedStack).
class FadeThroughBranches extends StatelessWidget {
  const FadeThroughBranches({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final reduced = OlMotion.reduced(context);
    final duration = reduced ? Duration.zero : OlTransitions.tab;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (i, child) in children.indexed)
          _Branch(active: i == currentIndex, duration: duration, child: child),
      ],
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({
    required this.active,
    required this.duration,
    required this.child,
  });

  final bool active;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: duration,
          // Masuk tertunda sedikit; keluar cepat → tidak ada dua layar bertumpuk jelas.
          curve: active
              ? const Interval(0.25, 1, curve: Curves.easeOut)
              : const Interval(0, 0.4, curve: Curves.easeIn),
          child: AnimatedScale(
            scale: active ? 1 : 0.98,
            duration: duration,
            curve: OlMotion.curve,
            // TickerMode di dalam animasi wadah: tab tak aktif berhenti beranimasi,
            // tapi fade-out tab itu sendiri tetap berjalan.
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}
