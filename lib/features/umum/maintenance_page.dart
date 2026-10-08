import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-03 Pemeliharaan: rekam sesi offline tetap bisa dipakai.
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return OlMessageScreen(
      illustration: OlIllustration.maintenance,
      title: 'Sistem sedang dipelihara',
      message: '',
      messageSpans: [
        const TextSpan(
          text: 'Kami sedang memperbarui server. Perkiraan selesai pukul ',
        ),
        TextSpan(
          text: '22.30 WIB',
          style: t.mono.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.ol.fg,
          ),
        ),
        const TextSpan(text: '.'),
      ],
      foot: [
        OlButton(
          label: 'Buka rekam sesi offline',
          onPressed: () => context.go('/terapis/jadwal'),
        ),
        OlButton.secondary(
          label: 'Coba lagi',
          onPressed: () =>
              context.feedback.info('Server masih dalam pemeliharaan.'),
        ),
      ],
      children: const [
        OlBanner(
          message:
              'Rekam sesi tetap bisa diisi. Catatan tersimpan di HP dan terkirim otomatis setelah pemeliharaan selesai.',
        ),
      ],
    );
  }
}
