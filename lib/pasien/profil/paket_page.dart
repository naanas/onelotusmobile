import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

/// PS-13 Paket & pembayaran: paket aktif + sisa kuota, tagihan belum lunas,
/// riwayat pembayaran & refund (ketuk → struk).
class PaketPage extends StatelessWidget {
  const PaketPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Paket & pembayaran',
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cedera Ringan 5×',
                      style: t.heading.copyWith(fontSize: 18),
                    ),
                  ),
                  const OlTag('Sisa 1', tone: OlTagTone.warn),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              Semantics(
                label: '4 dari 5 sesi terpakai',
                excludeSemantics: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(OlRadius.pill),
                  child: LinearProgressIndicator(
                    value: 0.8,
                    minHeight: 10,
                    backgroundColor: c.surfaceAlt,
                    color: c.brand,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '4 dari 5 sesi terpakai',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ),
                  Text(
                    'Berlaku s/d 30 Okt',
                    style: t.body.copyWith(color: c.muted),
                  ),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              OlButton(
                label: 'Perpanjang paket',
                onPressed: () => context.push(PRoutes.beliPaket),
              ),
            ],
          ),
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
                      'Belum lunas · Rp50.000',
                      style: t.bodyStrong.copyWith(fontSize: 16, color: c.warn),
                    ),
                    Text(
                      'Titik tambahan sesi 6 Okt',
                      style: t.body.copyWith(color: c.warn),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: OlSpace.sm),
              OlButton(
                label: 'Bayar sekarang',
                small: true,
                expand: false,
                onPressed: () => context.push(PRoutes.bayar),
              ),
            ],
          ),
        ),
        const OlOverline('RIWAYAT PEMBAYARAN'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, (title, sub, amount, refund)) in const [
                ('Paket Cedera Ringan 5×', '1 Sep · QRIS', 'Rp625.000', false),
                ('Kinesio tape', '29 Sep · tunai', 'Rp35.000', false),
                (
                  'Konsultasi awal',
                  '25 Agu · refund sebagian',
                  'Rp25.000',
                  true,
                ),
              ].indexed)
                OlListItem(
                  title: title,
                  subtitle: sub,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount,
                        style: t.mono.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      refund
                          ? const OlTag('Refund', tone: OlTagTone.muted)
                          : const OlTag('Lunas', tone: OlTagTone.ok),
                    ],
                  ),
                  divider: i < 2,
                  onTap: () => context.push(PRoutes.struk),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
