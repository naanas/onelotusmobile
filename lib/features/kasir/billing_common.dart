import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Tampilkan error API: pesan per field (422) sebagai toast info, lainnya lewat katalog §12.4.
void showApiError(BuildContext context, Object e) {
  if (e is! AppError) {
    context.feedback.error(const AppError(ErrorCode.unknown));
    return;
  }
  final field = e.fieldErrors.values.expand((v) => v).firstOrNull;
  if (field != null) {
    context.feedback.info(field);
  } else if (e.type == ErrorCode.unknown && e.apiMessage != null) {
    context.feedback.info(e.apiMessage!);
  } else if (!context.feedback.error(e) && e.apiMessage != null) {
    context.feedback.info(e.apiMessage!);
  }
}

/// Jalankan aksi; error ditampilkan, hasil null bila gagal.
Future<T?> runApi<T>(BuildContext context, Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    if (context.mounted) showApiError(context, e);
    return null;
  }
}

OlTagTone invoiceTone(String status) => switch (status) {
  'paid' => OlTagTone.ok,
  'cancelled' || 'refunded' => OlTagTone.strike,
  'awaiting_payment' => OlTagTone.warn,
  'partially_paid' || 'unpaid' => OlTagTone.crit,
  _ => OlTagTone.muted,
};

const itemKindLabels = {
  'service': 'Layanan',
  'extra_point': 'Titik tambahan',
  'injury_surcharge': 'Tambahan cedera',
  'transport': 'Transport',
  'package': 'Paket',
  'adjustment': 'Penyesuaian',
};

/// Rincian tagihan dengan urutan potongan §6.4.4: subtotal → member → voucher → manual → poin → total.
class InvoiceBreakdown extends StatelessWidget {
  const InvoiceBreakdown({super.key, required this.invoice, this.showPaid = true});

  final InvoiceV invoice;
  final bool showPaid;

  @override
  Widget build(BuildContext context) {
    final i = invoice;
    final manualLabel = switch (i.manualDiscountStatus) {
      'pending_approval' => '3 · Diskon manual (menunggu owner)',
      'rejected' => '3 · Diskon manual (ditolak)',
      _ => '3 · Diskon manual',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final it in i.items)
          OlMoneyRow(label: it.qty > 1 ? '${it.description} · ${it.qty}×' : it.description, amount: it.amount),
        const Divider(height: OlSpace.lg),
        OlMoneyRow(label: 'Subtotal', amount: i.subtotal),
        OlMoneyRow(label: '1 · Harga member', amount: i.memberDiscount, discount: true, empty: i.memberDiscount == 0),
        OlMoneyRow(
          label: i.voucherCode == null || i.voucherCode!.isEmpty ? '2 · Voucher' : '2 · Voucher ${i.voucherCode}',
          amount: i.voucherDiscount,
          discount: true,
          empty: i.voucherDiscount == 0,
        ),
        OlMoneyRow(label: manualLabel, amount: i.manualDiscount, discount: true, empty: i.manualDiscount == 0),
        OlMoneyRow(
          label: i.pointsUsed > 0 ? '4 · Poin Lotus (${i.pointsUsed})' : '4 · Poin Lotus',
          amount: i.pointsDiscount,
          discount: true,
          empty: i.pointsDiscount == 0,
        ),
        OlMoneyTotal(amount: i.total),
        if (showPaid && i.paid > 0) ...[
          const SizedBox(height: OlSpace.sm),
          OlMoneyRow(label: 'Sudah dibayar', amount: i.paid, muted: true),
          if (i.refunded > 0) OlMoneyRow(label: 'Direfund', amount: i.refunded, discount: true),
          OlMoneyRow(label: 'Sisa', amount: i.balance),
        ],
      ],
    );
  }
}

/// Kepala tagihan: pasien, nomor, terapis/tanggal, status.
class InvoiceHead extends StatelessWidget {
  const InvoiceHead({super.key, required this.invoice});
  final InvoiceV invoice;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final i = invoice;
    final meta = [
      Fmt.patientNo(i.patientNumber),
      ?i.therapistName,
      if (i.sessionDate != null) '${Fmt.dayShort(i.sessionDate!)} ${Fmt.time(i.sessionDate!)}',
      if (i.number != null) i.number!,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i.patientName, style: t.heading),
              const SizedBox(height: 2),
              Text(meta, style: t.caption.copyWith(color: c.muted)),
            ],
          ),
        ),
        OlTag(i.statusLabel, tone: invoiceTone(i.status)),
      ],
    );
  }
}

/// Lembar isian sederhana (voucher, diskon, nominal, catatan). `true` bila dikonfirmasi.
Future<bool> formSheet(
  BuildContext context, {
  required String title,
  String? message,
  required List<Widget> Function(StateSetter setState) fields,
  String confirm = 'Simpan',
}) async =>
    await context.feedback.sheet<bool>(
      title: title,
      message: message,
      child: StatefulBuilder(
        builder: (c, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final f in fields(setState)) ...[f, const SizedBox(height: OlSpace.md)],
            ],
          ),
        ),
      ),
      actions: [
        const SheetAction('Batal', false, variant: OlButtonVariant.secondary),
        SheetAction(confirm, true),
      ],
    ) ==
    true;

/// Ambil angka dari teks isian (titik/koma ribuan diabaikan).
int parseAmount(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

extension AsPage on Widget {
  /// Bungkus konten dalam kerangka layar turunan.
  Widget asPage(BuildContext context, String title, {List<Widget> foot = const []}) =>
      OlDetailScaffold(title: title, foot: foot, children: [this]);
}
