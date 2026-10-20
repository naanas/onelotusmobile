import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Filter { unpaid, waiting, partial, draft, paidToday }

/// KS-09 Tagihan (tab Kasir): daftar tagihan per status, pintasan kas & transaksi. Ketuk → rincian & bayar.
class TagihanPage extends ConsumerStatefulWidget {
  const TagihanPage({super.key});

  @override
  ConsumerState<TagihanPage> createState() => _TagihanPageState();
}

class _TagihanPageState extends ConsumerState<TagihanPage> {
  _Filter _filter = _Filter.unpaid;
  int _gen = 0;

  Future<List<InvoiceV>> _load() async {
    final api = ref.read(billingApiProvider);
    final page = await switch (_filter) {
      _Filter.unpaid => api.invoices(status: 'unpaid'),
      _Filter.waiting => api.invoices(status: 'awaiting_payment'),
      _Filter.partial => api.invoices(status: 'partially_paid'),
      _Filter.draft => api.invoices(status: 'draft'),
      _Filter.paidToday => api.invoices(status: 'paid', date: DateTime.now()),
    };
    return page.items;
  }

  Future<void> _open(InvoiceV i) async {
    await context.push(Routes.kasirTagihan(i.id));
    if (mounted) setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlPageBody(
      header: OlAppHeader(
        title: 'Kasir',
        actions: [
          OlIconButton(icon: OlIcons.history, semanticLabel: 'Riwayat transaksi', onPressed: () => context.push(Routes.kasirRiwayat)),
        ],
      ),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (label, route) in [
                ('Tutup kas', Routes.kasirTutupKas),
                ('Terima kas terapis', Routes.kasirTerimaKas),
                ('Verifikasi transfer', Routes.kasirVerifikasiTransfer),
                ('Piutang', Routes.kasirPiutang),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: OlSpace.sm),
                  child: OlChip(label: label, small: true, onTap: () => context.push(route)),
                ),
            ],
          ),
        ),
        OlSegmented<_Filter>(
          segments: const {
            _Filter.unpaid: 'Belum bayar',
            _Filter.waiting: 'Menunggu',
            _Filter.partial: 'Belum lunas',
            _Filter.draft: 'Draft',
            _Filter.paidToday: 'Lunas hari ini',
          },
          value: _filter,
          onChanged: (f) => setState(() {
            _filter = f;
            _gen++;
          }),
        ),
        OlAsync<List<InvoiceV>>(
          key: ValueKey((_filter, _gen)),
          load: _load,
          builder: (context, list, _) {
            if (list.isEmpty) {
              return const [
                OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptyInbox,
                    title: 'Tidak ada tagihan',
                    message: 'Tagihan dibuat otomatis saat terapis menyelesaikan sesi.',
                  ),
                ),
              ];
            }
            return [
              OlCard(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                child: Column(
                  children: [
                    for (final (n, i) in list.indexed)
                      OlListItem(
                        title: i.patientName,
                        subtitle: [
                          Fmt.patientNo(i.patientNumber),
                          i.number ?? 'Draft',
                          if (i.sessionDate != null) Fmt.dayShort(i.sessionDate!),
                        ].join(' · '),
                        leading: OlAvatar(name: i.patientName),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(Fmt.money(i.status == 'paid' ? i.total : i.balance), style: t.bodyStrong),
                            const SizedBox(height: 2),
                            Text(i.statusLabel, style: t.caption.copyWith(color: c.muted)),
                          ],
                        ),
                        divider: n < list.length - 1,
                        onTap: () => _open(i),
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
