import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// PS-16 Poin Lotus & referral: saldo, kode referral (salin), poin akan kedaluwarsa, riwayat poin.
class PoinPasienPage extends ConsumerWidget {
  const PoinPasienPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OlDetailScaffold(
    title: 'Poin & referral',
    children: [
      OlAsync<PointsSummaryV>(
        load: ref.read(pasienAppApiProvider).points,
        builder: (context, p, _) {
          final c = context.ol;
          final t = context.olText;
          return [
            OlCard(
              variant: OlCardVariant.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Poin Lotus', style: t.body.copyWith(color: c.muted)),
                  Text('${p.balance}', style: t.display),
                  if (p.valueRupiah > 0) Text('Senilai ${Fmt.money(p.valueRupiah)} untuk potongan tagihan', style: t.body),
                ],
              ),
            ),
            for (final e in p.expiring)
              if (e.points > 0 && e.at != null) OlBanner(message: '${e.points} poin kedaluwarsa ${Fmt.dateNoDay(e.at!)}.', tone: OlBannerTone.warn),
            if (p.referralCode != null)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Kode referral Anda', style: t.caption.copyWith(color: c.muted)),
                    Text(p.referralCode!, style: t.mono.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
                    if (p.referrals > 0) Text('${p.referrals} teman sudah bergabung', style: t.body.copyWith(color: c.muted)),
                    const SizedBox(height: OlSpace.md),
                    OlButton.secondary(
                      label: 'Salin kode',
                      icon: OlIcons.copy,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: p.referralCode!));
                        context.feedback.success('Kode disalin. Bagikan ke teman Anda.');
                      },
                    ),
                  ],
                ),
              ),
            if (p.history.isNotEmpty) ...[
              const OlSectionHeader(title: 'Riwayat'),
              OlCard(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                child: Column(
                  children: [
                    for (final (n, h) in p.history.indexed)
                      OlListItem(
                        title: h.reason.isEmpty ? (h.delta > 0 ? 'Poin masuk' : 'Poin dipakai') : h.reason,
                        subtitle: h.at == null ? null : Fmt.dateNoDay(h.at!),
                        trailing: Text('${h.delta > 0 ? '+' : ''}${h.delta}', style: t.bodyStrong.copyWith(color: h.delta > 0 ? c.ok : c.crit)),
                        divider: n < p.history.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ];
        },
      ),
    ],
  );
}
