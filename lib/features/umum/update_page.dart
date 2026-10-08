import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-02 Perbarui aplikasi (wajib — tidak bisa ditutup).
class UpdatePage extends StatelessWidget {
  const UpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return PopScope(
      canPop: false,
      child: OlMessageScreen(
        illustration: OlIllustration.update,
        title: 'Perbarui aplikasi dulu',
        message:
            'Versi yang terpasang sudah tidak didukung. Perbarui untuk melanjutkan — data yang tersimpan di HP aman dan akan tersinkron setelah pembaruan.',
        foot: [
          OlButton(
            label: 'Perbarui di Play Store',
            onPressed: () => context.feedback.info('Membuka Play Store…'),
          ),
        ],
        children: [
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OlInfoRow(
                  label: 'Terpasang',
                  value: 'v$kAppVersion',
                  valueStyle: t.mono.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                OlInfoRow(
                  label: 'Terbaru',
                  value: 'v1.2.0',
                  divider: true,
                  valueStyle: t.mono.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.brand,
                  ),
                ),
                const SizedBox(height: 12),
                Text('YANG BARU', style: t.overline),
                const SizedBox(height: 6),
                Text(
                  '• Rekam sesi lebih cepat dengan template',
                  style: t.body.copyWith(fontSize: 15),
                ),
                Text(
                  '• Perbaikan sinkron saat sinyal lemah',
                  style: t.body.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          const SyncIndicator(
            status: SyncSynced(),
            label: 'Semua data sudah tersinkron',
          ),
        ],
      ),
    );
  }
}
