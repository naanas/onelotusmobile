import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/json.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'billing_common.dart';

/// KS-11 Konfirmasi pembayaran & struk (§6.4.5): layar sukses, bukan toast. Struk tidak memuat catatan medis.
class StrukPage extends ConsumerStatefulWidget {
  const StrukPage({super.key, required this.receiptId});
  final String receiptId;

  @override
  ConsumerState<StrukPage> createState() => _StrukPageState();
}

class _StrukPageState extends ConsumerState<StrukPage> {
  bool _sending = false;

  BillingApi get _api => ref.read(billingApiProvider);

  Future<void> _send() async {
    setState(() => _sending = true);
    final ok = await runApi(context, () => _api.sendReceipt(widget.receiptId).then((_) => true));
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok == true) context.feedback.success('Struk dikirim ke WhatsApp pasien.');
  }

  Future<void> _pdf() async {
    final url = await runApi(context, () => _api.receiptPdf(widget.receiptId));
    if (url == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) context.feedback.info('Link PDF struk disalin (berlaku 5 menit).');
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Struk',
    close: true,
    foot: [
      OlButton(label: 'Selesai', onPressed: () => context.pop()),
    ],
    children: [
      OlAsync<ReceiptV>(
        load: () => _api.receipt(widget.receiptId),
        builder: (context, r, _) {
          final c = context.ol;
          final t = context.olText;
          final total = parseInt(r.breakdown['total']) ?? 0;
          final method = r.payments.map((p) => paymentMethodLabels[p.method] ?? p.method).toSet().join(' + ');
          return [
            OlCard(
              child: Column(
                children: [
                  OlIcon(OlIcons.checkCircle, weight: OlIconWeight.fill, size: 48, color: c.ok),
                  const SizedBox(height: OlSpace.sm),
                  Text('Pembayaran lunas', style: t.heading),
                  Text(Fmt.money(total), style: t.display),
                  Text(
                    [method, if ((r.changeGiven ?? 0) > 0) 'kembalian ${Fmt.money(r.changeGiven!)}'].join(' · '),
                    style: t.body.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('One Lotus · ${r.branchName}', style: t.bodyStrong),
                  Text(r.number, style: t.mono),
                  Text('${r.branchAddress} · ${Fmt.date(r.issuedAt)} ${Fmt.time(r.issuedAt)}', style: t.caption.copyWith(color: c.muted)),
                  const Divider(height: OlSpace.xl),
                  OlInfoRow(label: 'Pasien', value: '${r.patientName} · ${Fmt.patientNo(r.patientNumber)}'),
                  if (r.therapistName != null) OlInfoRow(label: 'Terapis', value: r.therapistName!),
                  const Divider(height: OlSpace.xl),
                  for (final it in r.items) OlMoneyRow(label: it.qty > 1 ? '${it.description} · ${it.qty}×' : it.description, amount: it.amount),
                  if ((parseInt(r.breakdown['member_discount']) ?? 0) > 0) OlMoneyRow(label: 'Harga member', amount: parseInt(r.breakdown['member_discount']), discount: true),
                  if ((parseInt(r.breakdown['voucher_discount']) ?? 0) > 0) OlMoneyRow(label: 'Voucher', amount: parseInt(r.breakdown['voucher_discount']), discount: true),
                  if ((parseInt(r.breakdown['manual_discount']) ?? 0) > 0) OlMoneyRow(label: 'Diskon', amount: parseInt(r.breakdown['manual_discount']), discount: true),
                  if ((parseInt(r.breakdown['points_discount']) ?? 0) > 0) OlMoneyRow(label: 'Poin', amount: parseInt(r.breakdown['points_discount']), discount: true),
                  OlMoneyTotal(amount: total),
                  const SizedBox(height: OlSpace.sm),
                  OlInfoRow(label: 'Metode', value: method),
                  if (r.packageRemaining != null) OlInfoRow(label: 'Sisa paket', value: '${r.packageRemaining} sesi'),
                  if (r.pointsEarned > 0) OlInfoRow(label: 'Poin didapat', value: '+${r.pointsEarned} poin'),
                  if (r.collectedBy.isNotEmpty) OlInfoRow(label: 'Kasir', value: r.collectedBy),
                  const SizedBox(height: OlSpace.sm),
                  Text('Struk tidak memuat catatan medis.', style: t.caption.copyWith(color: c.muted)),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(child: OlButton.secondary(label: r.lastSentAt == null ? 'Kirim WA' : 'Kirim ulang', icon: OlIcons.send, loading: _sending, onPressed: _send)),
                const SizedBox(width: OlSpace.sm),
                Expanded(child: OlButton.secondary(label: 'PDF', icon: OlIcons.download, onPressed: _pdf)),
              ],
            ),
          ];
        },
      ),
    ],
  );
}
