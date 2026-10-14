import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/auth/auth_controller.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-03 Pemeliharaan: rekam sesi offline tetap bisa dipakai.
class MaintenancePage extends ConsumerWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.olText;
    final until = ref.watch(appStatusProvider)?.maintenanceUntil;
    return OlMessageScreen(
      illustration: OlIllustration.maintenance,
      title: 'Sistem sedang dipelihara',
      message: '',
      messageSpans: [
        TextSpan(
          text: until == null
              ? 'Kami sedang memperbarui server. Silakan coba beberapa saat lagi'
              : 'Kami sedang memperbarui server. Perkiraan selesai pukul ',
        ),
        if (until != null)
          TextSpan(
            text: '${Fmt.time(until)} WIB',
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
          label: 'Coba lagi',
          onPressed: () async {
            try {
              final st = await ref.read(authRepositoryProvider).appStatus();
              ref.read(appStatusProvider.notifier).set(st);
              if (st.maintenance && context.mounted) {
                context.feedback.info('Server masih dalam pemeliharaan.');
              }
            } catch (_) {
              if (context.mounted) {
                context.feedback.info('Server belum bisa dihubungi.');
              }
            }
          },
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
