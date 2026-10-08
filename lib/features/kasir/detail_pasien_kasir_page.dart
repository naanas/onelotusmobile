import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-05 Detail pasien (kasir): nomor HP terlihat (§7), tagihan, paket, poin, jadwal, riwayat.
class DetailPasienKasirPage extends StatelessWidget {
  const DetailPasienKasirPage({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget visit(
      String date,
      String title,
      String sub,
      Widget tag, {
      bool divider = true,
    }) => Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(date, style: t.mono.copyWith(fontSize: 14)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(sub, style: t.body.copyWith(color: c.muted)),
              ],
            ),
          ),
          tag,
        ],
      ),
    );

    return OlDetailScaffold(
      title: '',
      actions: [
        OlButton.secondary(
          label: 'Edit',
          small: true,
          expand: false,
          onPressed: () => context.push(Routes.kasirPasienForm),
        ),
      ],
      foot: [
        OlFootRow(
          children: [
            OlButton.secondary(
              label: 'Buat jadwal',
              onPressed: () => context.push(Routes.kasirBuatJadwal),
            ),
            OlButton.secondary(
              label: 'Kirim link bayar',
              onPressed: () => context.feedback.success(
                'Link bayar terkirim ke WhatsApp pasien.',
              ),
            ),
          ],
        ),
      ],
      children: [
        Row(
          children: [
            const OlAvatar(name: 'Andi Pratama', large: true),
            const SizedBox(width: OlSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Andi Pratama', style: t.title),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '#0412',
                          style: t.mono.copyWith(color: c.muted),
                        ),
                        const TextSpan(text: ' · 34 th · Laki-laki · Member'),
                      ],
                    ),
                    style: t.body.copyWith(color: c.muted),
                  ),
                  Text(
                    '0812 3301 7745',
                    style: t.mono.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: c.warnSoft,
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tagihan belum lunas',
                      style: t.heading.copyWith(color: c.warn),
                    ),
                    Text(
                      'Sesi hari ini · Rp450.000',
                      style: t.body.copyWith(color: c.warn),
                    ),
                  ],
                ),
              ),
              OlButton(
                label: 'Tagih',
                small: true,
                expand: false,
                onPressed: () => context.go(Routes.kasirKasir),
              ),
            ],
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: OlCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paket', style: t.body.copyWith(color: c.muted)),
                      Text('—', style: t.heading),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.push(Routes.kasirJualPaket),
                        child: Text(
                          'Jual paket',
                          style: t.bodyStrong.copyWith(color: c.brand),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: OlCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Poin Lotus',
                        style: t.body.copyWith(color: c.muted),
                      ),
                      Text(
                        '1.120',
                        style: t.mono.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '= Rp112.000',
                        style: t.body.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const OlOverline('Jadwal mendatang'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: visit(
            '13 Okt',
            'Adjustment Therapy',
            '10.30 · Dimas',
            const OlTag('Dijadwalkan', tone: OlTagTone.outline),
            divider: false,
          ),
        ),
        const OlOverline('Riwayat kunjungan'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              visit(
                '6 Okt',
                'Adjustment · Dimas',
                'Ringkasan: nyeri 7→3',
                const OlTag('Belum bayar', tone: OlTagTone.warn),
              ),
              visit(
                '29 Sep',
                'Adjustment · Dimas',
                'Ringkasan: nyeri 8→6',
                const OlTag('Lunas', tone: OlTagTone.ok),
                divider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
