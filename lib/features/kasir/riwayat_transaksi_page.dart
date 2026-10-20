import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-13 Riwayat transaksi: per hari, filter metode; ketuk → rincian tagihan.
class RiwayatTransaksiPage extends ConsumerStatefulWidget {
  const RiwayatTransaksiPage({super.key});

  @override
  ConsumerState<RiwayatTransaksiPage> createState() => _RiwayatTransaksiPageState();
}

class _RiwayatTransaksiPageState extends ConsumerState<RiwayatTransaksiPage> {
  DateTime _day = DateTime.now();
  String? _method;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day).subtract(Duration(days: i))];
    return OlDetailScaffold(
      title: 'Riwayat transaksi',
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            children: [
              for (final d in days)
                Padding(
                  padding: const EdgeInsets.only(right: OlSpace.sm),
                  child: OlChip(
                    label: DateUtils.isSameDay(d, today) ? 'Hari ini' : Fmt.dayShort(d),
                    selected: DateUtils.isSameDay(d, _day),
                    onTap: () => setState(() => _day = d),
                  ),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: OlSpace.sm,
          children: [
            OlChip(label: 'Semua', small: true, selected: _method == null, onTap: () => setState(() => _method = null)),
            for (final m in ['cash', 'qris', 'transfer_manual', 'package'])
              OlChip(label: paymentMethodLabels[m]!, small: true, selected: _method == m, onTap: () => setState(() => _method = m)),
          ],
        ),
        OlAsync<List<InvoiceV>>(
          key: ValueKey((_day, _method)),
          load: () async => (await ref.read(billingApiProvider).invoices(date: _day, method: _method)).items,
          builder: (context, list, _) {
            final c = context.ol;
            final t = context.olText;
            final done = [for (final i in list) if (i.status != 'draft') i];
            if (done.isEmpty) {
              return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada transaksi', message: 'Tagihan yang diterbitkan hari itu muncul di sini.'))];
            }
            final total = done.where((i) => i.status == 'paid' || i.status == 'partially_paid').fold(0, (s, i) => s + i.paid - i.refunded);
            return [
              OlCard(child: OlMoneyRow(label: 'Diterima (${done.length} tagihan)', amount: total)),
              OlCard(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                child: Column(
                  children: [
                    for (final (n, i) in done.indexed)
                      OlListItem(
                        title: i.patientName,
                        subtitle: [i.number ?? '-', i.statusLabel].join(' · '),
                        trailing: Text(Fmt.money(i.total), style: t.bodyStrong.copyWith(color: i.status == 'cancelled' ? c.faint : null)),
                        divider: n < done.length - 1,
                        onTap: () => context.push(Routes.kasirTagihan(i.id)),
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
