import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_session.dart';

const _slides = [
  (
    OlIllustration.onboardRecovery,
    'Pantau pemulihan Anda',
    'Lihat nyeri yang terus berkurang dari sesi ke sesi, lengkap dengan catatan dari terapis.',
  ),
  (
    OlIllustration.onboardExercise,
    'Latihan dari terapis',
    'Video & langkah latihan di rumah, dengan pengingat harian agar tidak terlewat.',
  ),
  (
    OlIllustration.onboardBooking,
    'Booking tanpa antre',
    'Pilih layanan, terapis, dan jam yang cocok — di klinik atau home visit.',
  ),
];

/// PS-01 Onboarding: 3 layar perkenalan → masuk dengan nomor HP.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pages = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_i == _slides.length - 1) {
      ref.read(pasienSessionProvider.notifier).finishOnboarding();
      return;
    }
    _pages.nextPage(
      duration: OlMotion.of(context, OlMotion.slow),
      curve: OlMotion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OlStatusBar.dark,
      child: Scaffold(
        backgroundColor: c.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                  child: OlButton.text(
                    label: 'Lewati',
                    onPressed: () => ref
                        .read(pasienSessionProvider.notifier)
                        .finishOnboarding(),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _i = i),
                  children: [
                    for (final (ill, title, msg) in _slides)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: OlSpace.xxl,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OlIllustrationImage(ill, width: 280),
                            const SizedBox(height: OlSpace.xxl),
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: t.title.copyWith(fontSize: 26),
                              ),
                            ),
                            const SizedBox(height: OlSpace.sm),
                            Text(
                              msg,
                              textAlign: TextAlign.center,
                              style: t.body.copyWith(
                                fontSize: 15.5,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Semantics(
                label: 'Halaman ${_i + 1} dari ${_slides.length}',
                excludeSemantics: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var k = 0; k < _slides.length; k++)
                      AnimatedContainer(
                        duration: OlMotion.of(context),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: k == _i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: k == _i ? c.brand : c.line,
                          borderRadius: BorderRadius.circular(OlRadius.pill),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: OlSpace.xxl),
              OlFootBar(
                children: [
                  OlButton(
                    label: _i == _slides.length - 1 ? 'Mulai' : 'Lanjut',
                    onPressed: _next,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
