import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'billing_common.dart';

/// KS-15 Verifikasi transfer manual: bandingkan bukti dengan tagihan. Pengunggah tidak bisa memverifikasi sendiri.
class VerifikasiTransferPage extends ConsumerStatefulWidget {
  const VerifikasiTransferPage({super.key});

  @override
  ConsumerState<VerifikasiTransferPage> createState() => _VerifikasiTransferPageState();
}

class _VerifikasiTransferPageState extends ConsumerState<VerifikasiTransferPage> {
  int _gen = 0;

  BillingApi get _api => ref.read(billingApiProvider);

  Future<void> _proof(PaymentV y) async {
    final url = await runApi(context, () => _api.transferProof(y.id));
    if (url == null || !mounted) return;
    await context.feedback.sheet<void>(
      title: 'Bukti transfer',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OlRadius.input),
        child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Text('Gambar tidak bisa dimuat.')),
      ),
      actions: const [SheetAction('Tutup', null)],
    );
  }

  Future<void> _decide(PaymentV y, bool approve) async {
    String? reason;
    if (!approve) {
      final r = await context.feedback.choose(
        const ConfirmSpec(title: 'Tolak transfer?', message: 'Tagihan kembali belum bayar.', confirmLabel: 'Tolak', reasonLabel: 'Alasan'),
      );
      if (!r.confirmed) return;
      reason = r.reason;
    }
    if (!mounted) return;
    final res = await runApi(context, () => _api.verify(y.id, approve: approve, reason: reason));
    if (res == null || !mounted) return;
    context.feedback.success(approve ? 'Transfer diverifikasi. Tagihan ${res.invoice.statusLabel.toLowerCase()}.' : 'Transfer ditolak.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Verifikasi transfer',
    children: [
      OlAsync<List<PaymentV>>(
        key: ValueKey(_gen),
        load: _api.transfersToVerify,
        builder: (context, list, _) {
          final c = context.ol;
          final t = context.olText;
          if (list.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Tidak ada transfer menunggu', message: 'Bukti transfer dari kasir/terapis muncul di sini.'))];
          }
          return [
            for (final y in list)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(Fmt.money(y.amount), style: t.heading)),
                        const OlTag('Menunggu verifikasi', tone: OlTagTone.warn),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [?y.collectorName, if (y.createdAt != null) '${Fmt.dayShort(y.createdAt!)} ${Fmt.time(y.createdAt!)}'].join(' · '),
                      style: t.body.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: OlSpace.md),
                    OlButton.text(label: 'Lihat bukti', icon: OlIcons.eye, onPressed: () => _proof(y)),
                    OlFootRow(
                      children: [
                        OlButton.secondary(label: 'Tolak', small: true, onPressed: () => _decide(y, false)),
                        OlButton(label: 'Sesuai', small: true, onPressed: () => _decide(y, true)),
                      ],
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
