import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../demo_data.dart';

/// PS-16 Poin Lotus & referral: saldo, kode referral (salin/bagikan), riwayat poin.
class PoinPasienPage extends StatelessWidget {
  const PoinPasienPage({super.key});

  static const _code = 'RINA387';

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Poin Lotus',
      children: [
        OlCard(
          variant: OlCardVariant.gold,
          semanticLabel:
              '$demoPoints poin, senilai ${Fmt.money(demoPoints * demoPointValue)}. 40 poin kedaluwarsa 31 Desember 2026.',
          child: Column(
            children: [
              OlIcon(
                OlIcons.points,
                size: 40,
                color: c.gold,
                weight: OlIconWeight.duotone,
              ),
              const SizedBox(height: 6),
              Text(
                '$demoPoints',
                style: t.mono.copyWith(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: c.warn,
                ),
              ),
              Text(
                'poin · senilai ${Fmt.money(demoPoints * demoPointValue)}',
                style: t.body.copyWith(color: c.warn),
              ),
              const SizedBox(height: 4),
              Text(
                '40 poin kedaluwarsa 31 Des 2026',
                style: t.body.copyWith(fontSize: 14, color: c.warn),
              ),
            ],
          ),
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ajak teman, dapat 200 poin', style: t.heading),
              const SizedBox(height: 4),
              Text(
                'Teman Anda mendapat potongan Rp50.000 di transaksi pertama.',
                style: t.body.copyWith(fontSize: 14, color: c.muted),
              ),
              const SizedBox(height: OlSpace.md),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
                decoration: BoxDecoration(
                  color: c.surfaceAlt.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.faint.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _code,
                        style: t.mono.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    OlButton.text(
                      label: 'Salin',
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: _code));
                        context.feedback.success('Kode referral disalin.');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: OlSpace.md),
              OlButton(
                label: 'Bagikan kode',
                onPressed: () => context.feedback.info('Membuka menu bagikan…'),
              ),
              const SizedBox(height: 8),
              Text(
                '1 teman sudah bergabung · +200 poin',
                style: t.body.copyWith(fontSize: 14, color: c.muted),
              ),
            ],
          ),
        ),
        const OlOverline('RIWAYAT POIN'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, (title, date, n)) in const [
                ('Referral: Wulan', '12 Sep', 200),
                ('Pembelian paket', '1 Sep', 62),
                ('Dipakai: potongan konsultasi', '25 Agu', -22),
              ].indexed)
                OlListItem(
                  title: title,
                  subtitle: date,
                  trailing: Text(
                    n > 0 ? '+$n' : '$n',
                    style: t.mono.copyWith(
                      fontWeight: FontWeight.w700,
                      color: n > 0 ? c.ok : c.crit,
                    ),
                  ),
                  divider: i < 2,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
