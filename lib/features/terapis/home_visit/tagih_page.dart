import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/billing_api.dart';
import '../../../data/models/models.dart';
import '../../../ui/ui.dart';
import '../../kasir/bayar_page.dart';

/// TR-10 Tagih di lokasi: tagihan sesi home visit diterbitkan lalu dibayar tunai / QRIS / paket / link bayar.
/// Terapis tidak bisa menambah diskon atau mengubah harga.
class TagihPage extends ConsumerWidget {
  const TagihPage({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(billingApiProvider);
    return FutureBuilder<InvoiceV?>(
      future: () async {
        final inv = await api.invoiceForSession(sessionId);
        if (inv != null && inv.status == 'draft') return api.issue(inv.id);
        return inv;
      }(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const OlDetailScaffold(title: 'Tagih di lokasi', children: [OlLoadingCard()]);
        }
        final inv = snap.data;
        if (inv == null) {
          return OlDetailScaffold(
            title: 'Tagih di lokasi',
            children: [
              if (snap.hasError)
                OlErrorCard(message: snap.error is AppError ? (snap.error as AppError).message : 'Tagihan belum bisa dimuat.', onRetry: () {})
              else
                const OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptyInbox,
                    title: 'Tagihan belum ada',
                    message: 'Tagihan dibuat otomatis setelah sesi diselesaikan.',
                  ),
                ),
            ],
          );
        }
        return BayarPage(invoiceId: inv.id, homeVisit: true);
      },
    );
  }
}
