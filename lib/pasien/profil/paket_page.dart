import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

/// PS-13 Paket & pembayaran: paket aktif + sisa kuota, tagihan belum lunas, riwayat pembayaran (ketuk → struk).
class PaketPage extends ConsumerStatefulWidget {
  const PaketPage({super.key});

  @override
  ConsumerState<PaketPage> createState() => _PaketPageState();
}

class _PaketPageState extends ConsumerState<PaketPage> {
  int _gen = 0;

  Future<void> _go(String route) async {
    await context.push(route);
    if (mounted) setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(pasienAppApiProvider);
    return OlDetailScaffold(
      title: 'Paket & pembayaran',
      foot: [OlButton.secondary(label: 'Beli paket', icon: OlIcons.package, onPressed: () => _go(PRoutes.beliPaket))],
      children: [
        OlAsync<(List<OwnershipV>, List<InvoiceV>)>(
          key: ValueKey(_gen),
          load: () => (api.packages(), api.invoices()).wait,
          builder: (context, d, _) {
            final (pkgs, invoices) = d;
            final c = context.ol;
            final t = context.olText;
            final unpaid = [for (final i in invoices) if (i.payable && i.status != 'draft') i];
            final paid = [for (final i in invoices) if (i.receiptId != null) i];
            return [
              const OlSectionHeader(title: 'Paket saya'),
              if (pkgs.isEmpty)
                Text('Belum ada paket aktif.', style: t.body.copyWith(color: c.muted))
              else
                for (final p in pkgs)
                  OlCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(p.name, style: t.heading)),
                            if (p.status != 'active') OlTag(p.status == 'expired' ? 'Kedaluwarsa' : p.status == 'used_up' ? 'Habis' : p.status, tone: OlTagTone.muted),
                          ],
                        ),
                        const SizedBox(height: OlSpace.sm),
                        if (p.total > 0) OlMeterRow(label: 'Sisa ${p.remaining} dari ${p.total} sesi', value: p.remaining, max: p.total),
                        if (p.expiresOn != null) Text('Berlaku sampai ${Fmt.dateNoDay(p.expiresOn!)}', style: t.caption.copyWith(color: c.muted)),
                      ],
                    ),
                  ),
              if (unpaid.isNotEmpty) ...[
                const OlSectionHeader(title: 'Belum dibayar'),
                for (final i in unpaid)
                  OlCard(
                    onTap: () => _go('${PRoutes.bayar}?invoice=${i.id}'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.number ?? 'Tagihan', style: t.bodyStrong),
                              if (i.sessionDate != null) Text(Fmt.dayShort(i.sessionDate!), style: t.caption.copyWith(color: c.muted)),
                            ],
                          ),
                        ),
                        Text(Fmt.money(i.balance), style: t.bodyStrong.copyWith(color: c.crit)),
                        const SizedBox(width: OlSpace.sm),
                        OlIcon(OlIcons.chevronRight, color: c.faint),
                      ],
                    ),
                  ),
              ],
              if (paid.isNotEmpty) ...[
                const OlSectionHeader(title: 'Riwayat pembayaran'),
                OlCard(
                  padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                  child: Column(
                    children: [
                      for (final (n, i) in paid.indexed)
                        OlListItem(
                          title: i.number ?? 'Tagihan',
                          subtitle: [if (i.sessionDate != null) Fmt.dayShort(i.sessionDate!), i.statusLabel].join(' · '),
                          trailing: Text(Fmt.money(i.total), style: t.bodyStrong),
                          divider: n < paid.length - 1,
                          onTap: () => context.push('${PRoutes.struk}?id=${i.receiptId}'),
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
}
