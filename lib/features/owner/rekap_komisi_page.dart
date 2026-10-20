import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';

/// OW-07 Rekap komisi per bulan: estimasi → setujui → tandai dibayar. Angka dari aturan yang owner isi (OW-11).
class RekapKomisiPage extends ConsumerStatefulWidget {
  const RekapKomisiPage({super.key});

  @override
  ConsumerState<RekapKomisiPage> createState() => _RekapKomisiPageState();
}

class _RekapKomisiPageState extends ConsumerState<RekapKomisiPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _gen = 0;
  bool _busy = false;

  String get _period => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  Future<void> _act(bool paid, List<CommissionSummaryV> list) async {
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: paid ? 'Tandai komisi dibayar?' : 'Setujui komisi ${Fmt.monthShort(_month)}?',
        message: paid
            ? 'Komisi yang disetujui ditandai sudah dibayar ke terapis.'
            : 'Estimasi dikunci jadi angka final. Koreksi setelah ini tercatat sebagai penyesuaian.',
        confirmLabel: paid ? 'Tandai dibayar' : 'Setujui',
      ),
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await runApi(context, () => ref.read(billingApiProvider).commissionAction(_period, paid: paid));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) _gen++;
    });
    if (r != null) context.feedback.success(paid ? 'Komisi ditandai dibayar.' : 'Komisi disetujui.');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [for (var i = 3; i >= 0; i--) DateTime(now.year, now.month - i)];
    return OlDetailScaffold(
      title: 'Rekap komisi',
      actions: [OlIconButton(icon: OlIcons.settings, semanticLabel: 'Aturan komisi', onPressed: () => context.push(Routes.ownerAturanKomisi))],
      children: [
        OlSegmented<DateTime>(
          segments: {for (final m in months) m: Fmt.monthShort(m)},
          value: _month,
          onChanged: (m) => setState(() => _month = m),
        ),
        OlAsync<List<CommissionSummaryV>>(
          key: ValueKey((_period, _gen)),
          load: () => ref.read(billingApiProvider).commissions(period: _period),
          builder: (context, list, _) {
            final c = context.ol;
            final t = context.olText;
            if (list.isEmpty) {
              return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada komisi', message: 'Komisi tercatat saat terapis menyelesaikan sesi.'))];
            }
            final total = list.fold(0, (s, x) => s + x.total);
            final estimated = list.any((x) => x.status == 'estimated');
            final approved = list.any((x) => x.status == 'approved');
            return [
              OlCard(child: OlMoneyRow(label: 'Total ${list.length} terapis', amount: total)),
              OlCard(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                child: Column(
                  children: [
                    for (final (n, x) in list.indexed)
                      OlListItem(
                        title: x.staffName,
                        subtitle: [
                          '${x.sessions} sesi',
                          if (x.homeVisits > 0) '${x.homeVisits} home visit',
                          if (x.adjustments != 0) 'koreksi ${Fmt.money(x.adjustments)}',
                          commissionStatusLabels[x.status] ?? x.status,
                        ].join(' · '),
                        trailing: Text(Fmt.money(x.total), style: t.bodyStrong),
                        divider: n < list.length - 1,
                      ),
                  ],
                ),
              ),
              if (estimated) OlButton(label: 'Setujui semua', loading: _busy, onPressed: () => _act(false, list)),
              if (approved) OlButton.secondary(label: 'Tandai sudah dibayar', loading: _busy, onPressed: () => _act(true, list)),
              Text('Aturan komisi belum final dari workshop mitra; angka mengikuti aturan yang owner isi.', style: t.caption.copyWith(color: c.muted)),
            ];
          },
        ),
      ],
    );
  }
}
