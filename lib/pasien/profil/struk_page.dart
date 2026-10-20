import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/models/json.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// PS-15 Struk digital pasien: rincian, salin tautan PDF.
class StrukPasienPage extends ConsumerWidget {
  const StrukPasienPage({super.key, required this.receiptId});
  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(pasienAppApiProvider);
    return OlDetailScaffold(
      title: 'Struk',
      children: [
        OlAsync<ReceiptV>(
          load: () => api.receipt(receiptId),
          builder: (context, r, _) {
            final c = context.ol;
            final t = context.olText;
            final total = parseInt(r.breakdown['total']) ?? r.payments.fold<int>(0, (s, y) => s + y.amount);
            return [
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(r.branchName.isEmpty ? 'One Lotus' : r.branchName, style: t.heading, textAlign: TextAlign.center),
                    if (r.branchAddress.isNotEmpty) Text(r.branchAddress, style: t.caption.copyWith(color: c.muted), textAlign: TextAlign.center),
                    const SizedBox(height: OlSpace.sm),
                    Text('${r.number} · ${Fmt.dayShort(r.issuedAt)} ${Fmt.time(r.issuedAt)}', style: t.caption.copyWith(color: c.muted), textAlign: TextAlign.center),
                    if (r.therapistName != null) Text('Terapis ${r.therapistName}', style: t.caption.copyWith(color: c.muted), textAlign: TextAlign.center),
                    const Divider(height: OlSpace.xl),
                    for (final it in r.items) OlMoneyRow(label: it.qty > 1 ? '${it.description} · ${it.qty}×' : it.description, amount: it.amount),
                    OlMoneyTotal(amount: total),
                    const SizedBox(height: OlSpace.sm),
                    for (final y in r.payments) OlMoneyRow(label: paymentMethodLabels[y.method] ?? y.method, amount: y.amount, muted: true),
                    if (r.packageRemaining != null) Text('Sisa paket: ${r.packageRemaining} sesi', style: t.body),
                    if (r.pointsEarned > 0) Text('+${r.pointsEarned} Poin Lotus', style: t.bodyStrong.copyWith(color: c.brand)),
                  ],
                ),
              ),
              OlButton.secondary(
                label: 'Salin tautan PDF',
                icon: OlIcons.download,
                onPressed: () async {
                  final url = await runApi(context, () => api.receiptPdf(receiptId));
                  if (url == null || !context.mounted) return;
                  Clipboard.setData(ClipboardData(text: url));
                  context.feedback.success('Tautan PDF disalin. Buka di browser untuk menyimpan.');
                },
              ),
            ];
          },
        ),
      ],
    );
  }
}
