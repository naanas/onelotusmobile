import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../data/api/billing_api.dart';
import '../../../data/api/one_lotus_api.dart';
import '../../../data/models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';
import '../../kasir/billing_common.dart';

/// TR-11 Kas dibawa & serah terima ke kasir (§6.4.7): tunai home visit per hari → serahkan ke kasir.
class KasDibawaPage extends ConsumerStatefulWidget {
  const KasDibawaPage({super.key});

  @override
  ConsumerState<KasDibawaPage> createState() => _KasDibawaPageState();
}

class _KasDibawaPageState extends ConsumerState<KasDibawaPage> {
  int _gen = 0;

  Future<void> _handover(CashCarriedV day) async {
    final staff = await runApi(context, () => ref.read(oneLotusApiProvider).staff());
    if (staff == null || !mounted) return;
    final cashiers = [for (final s in staff) if (s.isActive) s.user];
    if (cashiers.isEmpty) return context.feedback.info('Belum ada kasir aktif di cabang ini.');
    final picked = await context.feedback.sheet<String>(
      title: 'Serahkan ${Fmt.money(day.total)}',
      message: 'Pilih kasir penerima. Kasir menghitung uang dan mengonfirmasi.',
      actions: [
        for (final u in cashiers) SheetAction(u.name, u.id, variant: OlButtonVariant.secondary),
      ],
    );
    if (picked == null || !mounted) return;
    final ok = await runApi(context, () => ref.read(billingApiProvider).handover(day.date, picked));
    if (ok == null || !mounted) return;
    context.feedback.success('Kas diserahkan. Menunggu kasir menerima.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Kas dibawa',
    children: [
      OlAsync<List<CashCarriedV>>(
        key: ValueKey(_gen),
        load: ref.read(billingApiProvider).myCash,
        builder: (context, days, _) {
          final c = context.ol;
          final t = context.olText;
          if (days.isEmpty) {
            return const [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptyInbox,
                  title: 'Tidak ada kas dibawa',
                  message: 'Pembayaran tunai saat home visit tercatat di sini sampai diserahkan ke kasir.',
                ),
              ),
            ];
          }
          final carried = days.where((d) => d.status == 'carried').fold(0, (s, d) => s + d.total);
          return [
            if (carried > 0) OlCard(variant: OlCardVariant.gold, child: OlMoneyRow(label: 'Belum diserahkan', amount: carried)),
            for (final d in days)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(Fmt.date(d.date), style: t.heading)),
                        OlTag(_status(d.status), tone: _tone(d.status)),
                      ],
                    ),
                    const SizedBox(height: OlSpace.sm),
                    for (final x in d.transactions)
                      OlMoneyRow(label: [x.patientName, if (x.at != null) Fmt.time(x.at!)].join(' · '), amount: x.amount, muted: true),
                    OlMoneyTotal(amount: d.total),
                    if (d.status == 'carried') ...[
                      const SizedBox(height: OlSpace.md),
                      OlButton(label: 'Serahkan ke kasir', small: true, onPressed: () => _handover(d)),
                    ] else if (d.status == 'handed_over')
                      Padding(
                        padding: const EdgeInsets.only(top: OlSpace.sm),
                        child: Text('Menunggu kasir menghitung & menerima.', style: t.caption.copyWith(color: c.muted)),
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

String _status(String s) => switch (s) {
  'carried' => 'Dibawa',
  'handed_over' => 'Diserahkan',
  'received' => 'Diterima',
  'received_with_diff' => 'Diterima, ada selisih',
  _ => s,
};

OlTagTone _tone(String s) => switch (s) {
  'carried' => OlTagTone.warn,
  'handed_over' => OlTagTone.outline,
  'received' => OlTagTone.ok,
  'received_with_diff' => OlTagTone.crit,
  _ => OlTagTone.muted,
};
