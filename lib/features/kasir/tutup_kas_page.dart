import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'billing_common.dart';

/// KS-17 Tutup kas harian: sistem vs dihitung, selisih wajib catatan, QRIS/VA menunggu harus selesai dulu.
/// Setelah ditutup, transaksi hari itu terkunci (koreksi hanya owner).
class TutupKasPage extends ConsumerStatefulWidget {
  const TutupKasPage({super.key});

  @override
  ConsumerState<TutupKasPage> createState() => _TutupKasPageState();
}

class _TutupKasPageState extends ConsumerState<TutupKasPage> {
  BillingApi get _api => ref.read(billingApiProvider);
  late Future<ClosingPreviewV> _future = _api.closingPreview();
  int? _counted;
  final _note = TextEditingController();
  bool _busy = false;

  Future<void> _close(ClosingPreviewV pv) async {
    final counted = _counted ?? pv.expected['cash'] ?? 0;
    final diff = counted - (pv.expected['cash'] ?? 0);
    if (diff != 0 && _note.text.trim().isEmpty) {
      return context.feedback.info(
        'Tulis penyebab selisih sebelum menutup kas.',
      );
    }
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: 'Tutup kas ${Fmt.dayShort(pv.date)}?',
        message:
            'Transaksi hari ini terkunci setelah ditutup. Ringkasan dikirim ke owner.',
        confirmLabel: 'Tutup kas',
        danger: false,
      ),
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await runApi(
      context,
      () => _api
          .closeCash(
            pv.date,
            counted,
            _note.text.trim().isEmpty ? null : _note.text.trim(),
          )
          .then((_) => true),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == true) {
      context.feedback.success('Kas ditutup.');
      context.pop();
    }
  }

  /// Tarik-untuk-memuat-ulang: data lama tetap tampil sampai data baru datang.
  Future<void> _pullRefresh() {
    final next = _api.closingPreview();
    setState(() {
      _future = next;
    });
    return next;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ClosingPreviewV>(
    future: _future,
    builder: (context, snap) {
      final pv = snap.data;
      final c = context.ol;
      final t = context.olText;
      return OlDetailScaffold(
        onRefresh: _pullRefresh,
        title: 'Tutup kas',
        context_: pv == null ? null : Fmt.date(pv.date),
        foot: [
          if (pv != null)
            OlButton(
              label: 'Tutup kas & kirim ke owner',
              loading: _busy,
              onPressed: pv.canClose ? () => _close(pv) : null,
            ),
        ],
        children: [
          if (snap.hasError)
            OlErrorCard(
              message: snap.error is AppError
                  ? (snap.error as AppError).message
                  : 'Data belum bisa dimuat.',
              onRetry: () => setState(() {
                _future = _api.closingPreview();
              }),
            )
          else if (pv == null)
            const OlLoadingCard()
          else ...[
            if (pv.blocking != null)
              OlBanner(message: pv.blocking!, tone: OlBannerTone.crit),
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OlMoneyRow(
                    label: 'Tunai di laci (sistem)',
                    amount: pv.expected['cash'] ?? 0,
                  ),
                  OlMoneyRow(
                    label: '· termasuk kas terapis diterima',
                    amount: pv.expected['therapist_cash_received'] ?? 0,
                    muted: true,
                  ),
                  OlMoneyRow(
                    label: '· dikurangi refund tunai',
                    amount: pv.expected['cash_refunds'] ?? 0,
                    muted: true,
                  ),
                  OlMoneyRow(label: 'QRIS', amount: pv.expected['qris'] ?? 0),
                  OlMoneyRow(
                    label: 'Transfer / VA',
                    amount:
                        (pv.expected['transfer_manual'] ?? 0) +
                        (pv.expected['va'] ?? 0),
                  ),
                  OlMoneyRow(
                    label: 'E-wallet / link',
                    amount:
                        (pv.expected['ewallet'] ?? 0) +
                        (pv.expected['payment_link'] ?? 0),
                  ),
                  OlMoneyRow(
                    label: 'Pakai paket',
                    amount: pv.expected['package'] ?? 0,
                    muted: true,
                  ),
                ],
              ),
            ),
            if (pv.therapistCash.any((h) => h.status == 'handed_over'))
              OlBanner(
                message:
                    '${pv.therapistCash.where((h) => h.status == 'handed_over').length} kas terapis belum diterima.',
                tone: OlBannerTone.warn,
              ),
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OlMoneyField(
                    label: 'Uang tunai fisik',
                    isRequired: true,
                    value: _counted ?? pv.expected['cash'] ?? 0,
                    onChanged: (v) => setState(() => _counted = v),
                  ),
                  const SizedBox(height: OlSpace.md),
                  Builder(
                    builder: (context) {
                      final diff =
                          (_counted ?? pv.expected['cash'] ?? 0) -
                          (pv.expected['cash'] ?? 0);
                      return OlMoneyRow(
                        label: diff == 0
                            ? 'Selisih tunai'
                            : 'Selisih tunai · wajib catatan',
                        amount: diff,
                      );
                    },
                  ),
                  const SizedBox(height: OlSpace.md),
                  OlTextField(
                    label: 'Catatan selisih',
                    controller: _note,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            for (final y in pv.openGateway)
              Text(
                '• ${paymentMethodLabels[y.method]} ${Fmt.money(y.amount)} masih menunggu.',
                style: t.body.copyWith(color: c.crit),
              ),
          ],
        ],
      );
    },
  );
}
