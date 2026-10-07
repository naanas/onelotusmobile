import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/auth/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-01 Splash & cek versi. Navigasi selanjutnya ditangani redirect router.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_boot);
  }

  void _boot() => ref.read(authProvider.notifier).bootstrap();

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final phase = ref.watch(authProvider.select((s) => s.phase));
    final noConnection = phase == AuthPhase.needsConnection;
    const sub = Color(0xFFBAE6FD);

    return Scaffold(
      backgroundColor: const Color(0xFF0C4A6E),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const OlLogoMark(),
                  const SizedBox(height: 30),
                  Text(
                    'One Lotus',
                    style: t.display.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Personal Therapy · Aplikasi Staf',
                    style: t.body.copyWith(color: sub),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
              child: noConnection
                  ? Column(
                      children: [
                        Text(
                          'Butuh koneksi untuk masuk pertama kali.',
                          textAlign: TextAlign.center,
                          style: t.bodyStrong.copyWith(color: Colors.white),
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
                    )
                  : Column(
                      children: [
                        SizedBox(
                          width: 160,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              color: const Color(0xFF38BDF8),
                              value: OlMotion.reduced(context) ? 0.6 : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Memeriksa sesi login…',
                          style: t.body.copyWith(fontSize: 13, color: sub),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'v$kAppVersion',
                style: t.mono.copyWith(
                  fontSize: 12,
                  color: const Color(0xFF7FB3CF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
