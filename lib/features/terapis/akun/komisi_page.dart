import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../data/api/billing_api.dart';
import '../../../data/models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

/// TR-12 Komisi saya: estimasi sampai disetujui owner. Aturan komisi dari owner (TODO(workshop) §16 no. 2).
class KomisiPage extends ConsumerStatefulWidget {
  const KomisiPage({super.key});

  @override
  ConsumerState<KomisiPage> createState() => _KomisiPageState();
}

class _KomisiPageState extends ConsumerState<KomisiPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _period => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [for (var i = 3; i >= 0; i--) DateTime(now.year, now.month - i)];
    return OlDetailScaffold(
      title: 'Komisi saya',
      children: [
        OlSegmented<DateTime>(
          segments: {for (final m in months) m: Fmt.monthShort(m)},
          value: _month,
          onChanged: (m) => setState(() => _month = m),
        ),
        OlAsync<CommissionSummaryV>(
          key: ValueKey(_period),
          load: () => ref.read(billingApiProvider).myCommissions(period: _period),
          builder: (context, s, _) {
            final c = context.ol;
            final t = context.olText;
            return [
              OlCard(
                variant: OlCardVariant.now,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Total ${Fmt.monthShort(_month)}', style: t.body.copyWith(color: c.muted))),
                        OlTag(commissionStatusLabels[s.status] ?? s.status, tone: s.status == 'paid' ? OlTagTone.ok : s.status == 'approved' ? OlTagTone.brand : OlTagTone.outline),
                      ],
                    ),
                    const SizedBox(height: OlSpace.xs),
                    Text(Fmt.money(s.total), style: t.display),
                    const SizedBox(height: OlSpace.xs),
                    Text(
                      [
                        '${s.sessions} sesi',
                        if (s.homeVisits > 0) '${s.homeVisits} home visit',
                        if (s.adjustments != 0) 'koreksi ${Fmt.money(s.adjustments)}',
                      ].join(' · '),
                      style: t.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              if (s.status == 'estimated')
                const OlBanner(message: 'Masih estimasi. Angka final setelah disetujui owner di akhir bulan.', tone: OlBannerTone.info),
              if (s.items.isEmpty)
                const OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada komisi', message: 'Komisi tercatat otomatis setiap sesi selesai.'))
              else
                OlCard(
                  padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                  child: Column(
                    children: [
                      for (final (n, i) in s.items.indexed)
                        OlListItem(
                          title: i.isCorrection ? 'Koreksi · ${i.label}' : '${i.patientInitials} · ${i.label}',
                          subtitle: i.date == null ? null : Fmt.dayShort(i.date!),
                          trailing: Text(Fmt.money(i.amount), style: t.bodyStrong.copyWith(color: i.amount < 0 ? c.crit : null)),
                          divider: n < s.items.length - 1,
                        ),
                    ],
                  ),
                ),
            ];
          },
        ),
      ],
    );
  }
}
