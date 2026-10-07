import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../core/format.dart';
import '../../data/auth/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Warna splash — sama dengan native splash Android (res/values/colors.xml) agar perpindahan mulus.
const kSplashBg = Color(0xFF0C4A6E);

/// UM-01 Splash & cek versi: lotus mekar (an_splash_lotus, D.3), lalu nama & subjudul muncul.
/// Navigasi selanjutnya ditangani redirect router.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  /// Splash tampil minimal selama ini (animasi 1,2 dtk + jeda singkat).
  static const minDuration = Duration(milliseconds: 1400);

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      if (OlMotion.reduced(context)) {
        _ctrl.value = 1;
      } else {
        _ctrl.forward();
      }
      _boot(first: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _boot({bool first = false}) => ref
      .read(authProvider.notifier)
      .bootstrap(
        minDuration: first && !OlMotion.reduced(context)
            ? SplashPage.minDuration
            : Duration.zero,
      );

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final noConnection = ref.watch(
      authProvider.select((s) => s.phase == AuthPhase.needsConnection),
    );
    const sub = Color(0xFFBAE6FD);

    Animation<double> interval(double a, double b) => CurvedAnimation(
      parent: _ctrl,
      curve: Interval(a, b, curve: OlMotion.curve),
    );

    Widget rise(Animation<double> a, Widget child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OlStatusBar.splash,
      child: Scaffold(
        backgroundColor: kSplashBg,
        body: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const Spacer(flex: 5),
                Semantics(
                  label: 'One Lotus',
                  child: SizedBox.square(
                    dimension: 132,
                    child: Lottie.asset(
                      'assets/lottie/an_splash_lotus.json',
                      controller: _ctrl,
                      frameRate: FrameRate.max,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                rise(
                  interval(0.45, 0.9),
                  Text(
                    'One Lotus',
                    style: t.display.copyWith(
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                rise(
                  interval(0.6, 1),
                  Text(
                    'Personal Therapy · Aplikasi Staf',
                    style: t.body.copyWith(color: sub),
                  ),
                ),
                const Spacer(flex: 6),
                AnimatedSwitcher(
                  duration: OlMotion.of(context),
                  child: noConnection
                      ? Padding(
                          key: const ValueKey('offline'),
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            children: [
                              Text(
                                'Butuh koneksi untuk masuk pertama kali.',
                                textAlign: TextAlign.center,
                                style: t.bodyStrong.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Periksa sinyal atau Wi-Fi, lalu coba lagi.',
                                textAlign: TextAlign.center,
                                style: t.body.copyWith(color: sub),
                              ),
                              const SizedBox(height: 16),
                              OlButton(
                                label: 'Coba lagi',
                                icon: OlIcons.refresh,
                                onPressed: _boot,
                              ),
                            ],
                          ),
                        )
                      : FadeTransition(
                          key: const ValueKey('loading'),
                          opacity: interval(0.8, 1),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 120,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.14,
                                    ),
                                    color: const Color(0xFF38BDF8),
                                    value: OlMotion.reduced(context)
                                        ? 0.6
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Memeriksa sesi login…',
                                style: t.body.copyWith(
                                  fontSize: 13,
                                  color: sub,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 28),
                Text(
                  'v$kAppVersion',
                  style: t.mono.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF7FB3CF),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
