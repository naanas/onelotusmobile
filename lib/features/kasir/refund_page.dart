import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'billing_common.dart';

/// KS-14 Refund / batal transaksi (§6.4.6): jenis → nominal → alasan → metode → dampak otomatis.
/// Di atas batas owner (refund_approval_threshold) masuk persetujuan; refund QRIS/VA dicatat manual.
class RefundPage extends ConsumerStatefulWidget {
  const RefundPage({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<RefundPage> createState() => _RefundPageState();
}

const _reasons = {
  'batal_layanan': 'Layanan batal',
  'keluhan': 'Keluhan pasien',
  'salah_tagih': 'Salah tagih',
  'lainnya': 'Lainnya',
};

const _methods = {
  'cash': 'Tunai',
  'transfer_manual': 'Transfer',
  'package_quota': 'Kembalikan kuota paket',
  'points': 'Kembalikan poin',
};

class _RefundPageState extends ConsumerState<RefundPage> {
  BillingApi get _api => ref.read(billingApiProvider);
  late final Future<InvoiceV> _future = _api.invoice(widget.invoiceId);

  bool _full = true;
  int _amount = 0;
  String _reason = 'batal_layanan';
  String _method = 'cash';
  final _note = TextEditingController();
  bool _busy = false;

  Future<void> _submit(InvoiceV inv) async {
    final amount = _full ? inv.paid - inv.refunded : _amount;
    if (amount <= 0) return context.feedback.info('Isi nominal refund.');
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: 'Refund ${Fmt.money(amount)}?',
        message: 'Poin dari tagihan ini dan komisi terapis ikut dikoreksi otomatis.',
        confirmLabel: 'Proses refund',
      ),
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await runApi(
      context,
      () => _api.refund(inv.id, {
        'kind': _full ? 'full' : 'partial',
        'amount': amount,
        'reason_code': _reason,
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'method': _method,
      }),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) return;
    context.feedback.success(r.status == 'requested' ? 'Refund menunggu persetujuan owner.' : 'Refund ${Fmt.money(r.amount)} diproses.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<InvoiceV>(
    future: _future,
    builder: (context, snap) {
      final inv = snap.data;
      return OlDetailScaffold(
        title: 'Refund / batal',
        close: true,
        foot: [if (inv != null) OlButton(label: 'Proses refund', loading: _busy, onPressed: () => _submit(inv))],
        children: [
          if (snap.hasError)
            OlErrorCard(message: snap.error is AppError ? (snap.error as AppError).message : 'Tagihan belum bisa dimuat.', onRetry: () {})
          else if (inv == null)
            const OlLoadingCard()
          else ...[
            OlCard(child: InvoiceHead(invoice: inv)),
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OlSegmented<bool>(
                    segments: {true: 'Penuh ${Fmt.money(inv.paid - inv.refunded)}', false: 'Sebagian'},
                    value: _full,
                    onChanged: (v) => setState(() => _full = v),
                  ),
                  if (!_full) ...[
                    const SizedBox(height: OlSpace.md),
                    OlMoneyField(label: 'Nominal refund', value: _amount, onChanged: (v) => setState(() => _amount = v)),
                  ],
                ],
              ),
            ),
            const OlSectionHeader(title: 'Alasan'),
            Wrap(
              spacing: OlSpace.sm,
              runSpacing: OlSpace.sm,
              children: [
                for (final r in _reasons.entries)
                  OlChip(label: r.value, selected: _reason == r.key, onTap: () => setState(() => _reason = r.key)),
              ],
            ),
            OlTextField(label: 'Catatan', controller: _note, maxLines: 3),
            const OlSectionHeader(title: 'Dikembalikan lewat'),
            Wrap(
              spacing: OlSpace.sm,
              runSpacing: OlSpace.sm,
              children: [
                for (final m in _methods.entries)
                  OlChip(label: m.value, selected: _method == m.key, onTap: () => setState(() => _method = m.key)),
              ],
            ),
            Text(
              'Refund QRIS/VA tidak bisa otomatis — kembalikan lewat tunai/transfer dan catat di sini.',
              style: context.olText.caption.copyWith(color: context.ol.muted),
            ),
          ],
        ],
      );
    },
  );
}
