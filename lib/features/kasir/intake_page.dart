import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-02 Intake QR: QR besar untuk discan pasien, daftar "baru masuk" langsung.
class IntakePage extends StatefulWidget {
  const IntakePage({super.key});

  @override
  State<IntakePage> createState() => _IntakePageState();
}

class _IntakePageState extends State<IntakePage> {
  int _seed = 2;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Intake pasien baru',
      close: true,
      actions: [
        TextButton(
          onPressed: () => context.push(Routes.kasirPasienForm),
          style: TextButton.styleFrom(
            foregroundColor: c.brand,
            textStyle: t.button,
          ),
          child: const Text('Input manual'),
        ),
      ],
      children: [
        OlCard(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              PseudoQr(
                seed: _seed,
                semanticLabel: 'Kode QR form intake untuk dipindai pasien',
              ),
              const SizedBox(height: 14),
              Text('Minta pasien scan QR ini', style: t.heading),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Form intake · Klinik Pusat Malang · ',
                    style: t.body.copyWith(color: c.muted),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _seed++);
                      context.feedback.info(
                        'QR baru dibuat. QR lama tidak berlaku.',
                      );
                    },
                    child: Text(
                      'Ganti QR',
                      style: t.bodyStrong.copyWith(color: c.brand),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Baru masuk',
                style: t.heading.copyWith(fontSize: 17),
              ),
            ),
            const SyncIndicator(
              status: SyncSaving(),
              label: 'Diperbarui langsung',
            ),
          ],
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              OlListItem(
                leading: const OlAvatar(name: 'Sari Wulandari'),
                title: 'Sari Wulandari',
                subtitle: 'Masuk 14.41 · keluhan LBP · TB/BB lengkap',
                trailing: const OlTag('Verifikasi'),
                onTap: () => context.push(Routes.kasirPasienForm),
              ),
              OlListItem(
                leading: const OlAvatar(name: 'Rizky Hakim'),
                title: 'Rizky Hakim',
                subtitle: 'Masuk kemarin 17.20',
                trailing: const OlTag('>24 jam', tone: OlTagTone.crit),
                divider: false,
                onTap: () => context.push(Routes.kasirPasienForm),
              ),
            ],
          ),
        ),
        Text(
          'Nomor pasien dibuat server saat data disimpan. Sistem mengecek data ganda (nama + tanggal lahir, atau nomor HP) sebelum menyimpan.',
          style: t.body.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
