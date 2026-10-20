import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'billing_common.dart';

/// KS-09 rincian tagihan: urutan potongan §6.4.4, voucher, diskon manual (wajib alasan; di atas batas → owner),
/// poin, terbitkan, bayar, batal, struk, refund.
class InvoiceDetailPage extends ConsumerStatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends ConsumerState<InvoiceDetailPage> {
  int _gen = 0;
  bool _busy = false;

  BillingApi get _api => ref.read(billingApiProvider);

  void _reload() => setState(() => _gen++);

  Future<void> _do(Future<Object?> Function() action, String done) async {
    setState(() => _busy = true);
    final ok = await runApi(context, action) != null;
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      HapticFeedback.lightImpact();
      context.feedback.success(done);
      _reload();
    }
  }

  Future<void> _voucher(InvoiceV i) async {
    final code = TextEditingController(text: i.voucherCode ?? '');
    final ok = await formSheet(
      context,
      title: 'Voucher',
      message: 'Kosongkan untuk melepas voucher.',
      fields: (_) => [
        OlTextField(label: 'Kode voucher', controller: code, textInputAction: TextInputAction.done),
      ],
    );
    if (!ok) return;
    final v = code.text.trim();
    await _do(() => _api.updateInvoice(i.id, {'voucher_code': v.isEmpty ? null : v}), v.isEmpty ? 'Voucher dilepas.' : 'Voucher dipakai.');
  }

  Future<void> _discount(InvoiceV i) async {
    var type = 'amount';
    final value = TextEditingController();
    final reason = TextEditingController();
    final ok = await formSheet(
      context,
      title: 'Diskon manual',
      message: 'Alasan wajib. Di atas batas yang diatur owner, diskon menunggu persetujuan.',
      fields: (set) => [
        OlSegmented<String>(
          segments: const {'amount': 'Nominal (Rp)', 'percent': 'Persen'},
          value: type,
          onChanged: (v) => set(() => type = v),
        ),
        OlTextField(label: type == 'percent' ? 'Diskon (%)' : 'Diskon (Rp)', controller: value, keyboardType: TextInputType.number),
        OlTextField(label: 'Alasan', controller: reason, isRequired: true),
      ],
    );
    if (!ok) return;
    final n = parseAmount(value.text);
    await _do(
      () => _api.updateInvoice(i.id, {
        'manual_discount': n == 0 ? null : {'type': type, 'value': n, 'reason': reason.text.trim()},
      }),
      n == 0 ? 'Diskon dihapus.' : 'Diskon disimpan.',
    );
  }

  Future<void> _points(InvoiceV i) async {
    final pts = TextEditingController(text: i.pointsUsed > 0 ? '${i.pointsUsed}' : '');
    PointsSummaryV? sum;
    if (i.patientId != null) sum = await runApi(context, () => _api.patientPoints(i.patientId!));
    if (!mounted) return;
    final ok = await formSheet(
      context,
      title: 'Pakai poin',
      message: sum == null ? null : 'Saldo ${sum.balance} poin (${Fmt.money(sum.valueRupiah)}).',
      fields: (_) => [OlTextField(label: 'Jumlah poin', controller: pts, keyboardType: TextInputType.number)],
    );
    if (!ok) return;
    final n = parseAmount(pts.text);
    await _do(() => _api.updateInvoice(i.id, {'points_to_use': n == 0 ? null : n}), n == 0 ? 'Poin tidak dipakai.' : 'Poin dipakai.');
  }

  Future<void> _cancel(InvoiceV i) async {
    final r = await context.feedback.choose(
      ConfirmSpec(
        title: 'Batalkan tagihan?',
        message: 'Tagihan dibatalkan dan tercatat di audit log.',
        confirmLabel: 'Batalkan tagihan',
        reasonLabel: 'Alasan',
      ),
    );
    if (!r.confirmed) return;
    await _do(() => _api.cancelInvoice(i.id, r.reason ?? ''), 'Tagihan dibatalkan.');
  }

  Future<void> _pay(InvoiceV i) async {
    await context.push(Routes.bayar(i.id));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => OlAsync<InvoiceV>(
    key: ValueKey(_gen),
    load: () => _api.invoice(widget.invoiceId),
    builder: (context, i, _) => [_body(context, i)],
  ).asPage(context, 'Tagihan');

  Widget _body(BuildContext context, InvoiceV i) {
    final c = context.ol;
    final t = context.olText;
    final editable = i.status == 'draft' || i.status == 'unpaid';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InvoiceHead(invoice: i),
              const SizedBox(height: OlSpace.md),
              InvoiceBreakdown(invoice: i),
            ],
          ),
        ),
        if (i.manualDiscountStatus == 'pending_approval') ...[
          const SizedBox(height: OlSpace.gap),
          const OlBanner(message: 'Diskon menunggu persetujuan owner. Tagihan belum bisa dibayar.', tone: OlBannerTone.warn),
        ],
        if (editable) ...[
          const SizedBox(height: OlSpace.gap),
          Wrap(
            spacing: OlSpace.sm,
            runSpacing: OlSpace.sm,
            children: [
              OlChip(label: 'Voucher', icon: OlIcons.voucher, onTap: _busy ? null : () => _voucher(i)),
              OlChip(label: 'Diskon', icon: OlIcons.percent, onTap: _busy ? null : () => _discount(i)),
              OlChip(label: 'Poin', icon: OlIcons.points, onTap: _busy ? null : () => _points(i)),
            ],
          ),
        ],
        if (i.payments.isNotEmpty) ...[
          const SizedBox(height: OlSpace.gap),
          const OlSectionHeader(title: 'Pembayaran'),
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (n, y) in i.payments.indexed)
                  OlListItem(
                    title: '${paymentMethodLabels[y.method] ?? y.method} · ${Fmt.money(y.amount)}',
                    subtitle: [
                      _paymentStatus(y.status),
                      if (y.paidAt != null) '${Fmt.dayShort(y.paidAt!)} ${Fmt.time(y.paidAt!)}',
                      ?y.collectorName,
                    ].join(' · '),
                    divider: n < i.payments.length - 1,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: OlSpace.lg),
        if (i.status == 'draft')
          OlButton(label: 'Terbitkan tagihan', loading: _busy, onPressed: () => _do(() => _api.issue(i.id), 'Tagihan diterbitkan.')),
        if (i.payable && i.status != 'draft') ...[
          const SizedBox(height: OlSpace.sm),
          OlButton(label: 'Bayar ${Fmt.money(i.balance)}', onPressed: i.manualDiscountStatus == 'pending_approval' ? null : () => _pay(i)),
        ],
        if (i.receiptId != null) ...[
          const SizedBox(height: OlSpace.sm),
          OlButton.secondary(label: 'Lihat struk', icon: OlIcons.receipt, onPressed: () => context.push(Routes.struk(i.receiptId!))),
        ],
        if (i.refundable) ...[
          const SizedBox(height: OlSpace.sm),
          OlButton.secondary(
            label: 'Refund',
            onPressed: () async {
              await context.push(Routes.refund(i.id));
              if (mounted) _reload();
            },
          ),
        ],
        if (editable) ...[
          const SizedBox(height: OlSpace.sm),
          OlButton.text(label: 'Batalkan tagihan', onPressed: _busy ? null : () => _cancel(i), expand: true),
        ],
        const SizedBox(height: OlSpace.sm),
        Text(
          'Total dihitung server dari harga saat sesi. Komisi terapis tercatat otomatis.',
          style: t.caption.copyWith(color: c.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

String _paymentStatus(String s) => switch (s) {
  'succeeded' => 'Berhasil',
  'pending' => 'Menunggu',
  'awaiting_verification' => 'Menunggu verifikasi',
  'failed' => 'Gagal',
  'expired' => 'Kedaluwarsa',
  'rejected' => 'Ditolak',
  'cancelled' => 'Dibatalkan',
  _ => s,
};

