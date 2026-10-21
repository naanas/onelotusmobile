import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'owner_forms.dart';

/// OW-13 Poin Lotus & referral: aturan dari `app_config` (TODO(workshop) §16 no. 14). Nilai 0 = fitur mati.
class PoinPage extends ConsumerStatefulWidget {
  const PoinPage({super.key});

  @override
  ConsumerState<PoinPage> createState() => _PoinPageState();
}

class _PoinPageState extends ConsumerState<PoinPage> {
  BillingApi get _api => ref.read(billingApiProvider);
  late Future<PointsRulesV> _future = _api.pointsRules();
  final _c = {
    for (final k in ['earn', 'value', 'max', 'expiry', 'referrer', 'referee'])
      k: TextEditingController(),
  };
  bool _filled = false, _busy = false;

  void _fill(PointsRulesV r) {
    if (_filled) return;
    _filled = true;
    _c['earn']!.text = '${r.earnPerRupiah}';
    _c['value']!.text = '${r.pointValue}';
    _c['max']!.text = '${r.maxRedeemPercent}';
    _c['expiry']!.text = '${r.expiryDays}';
    _c['referrer']!.text = '${r.referrer}';
    _c['referee']!.text = '${r.referee}';
  }

  int _v(String k) => parseAmount(_c[k]!.text);

  Future<void> _save() async {
    setState(() => _busy = true);
    final r = await runApi(
      context,
      () => _api.savePointsRules(
        PointsRulesV(
          earnPerRupiah: _v('earn'),
          pointValue: _v('value'),
          maxRedeemPercent: _v('max'),
          expiryDays: _v('expiry'),
          referrer: _v('referrer'),
          referee: _v('referee'),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) context.feedback.success('Aturan poin disimpan.');
  }

  /// Tarik-untuk-memuat-ulang: data lama tetap tampil sampai data baru datang.
  Future<void> _pullRefresh() {
    final next = _api.pointsRules();
    setState(() {
      _filled = false;
      _future = next;
    });
    return next;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PointsRulesV>(
    future: _future,
    builder: (context, snap) {
      if (snap.hasData) _fill(snap.data!);
      final t = context.olText;
      final c = context.ol;
      final earn = _filled ? _v('earn') : 0;
      final value = _filled ? _v('value') : 0;
      return OlDetailScaffold(
        onRefresh: _pullRefresh,
        title: 'Poin & referral',
        foot: [
          if (snap.hasData)
            OlButton(label: 'Simpan', loading: _busy, onPressed: _save),
        ],
        children: [
          if (snap.hasError)
            OlErrorCard(
              message: snap.error is AppError
                  ? (snap.error as AppError).message
                  : 'Aturan poin belum bisa dimuat.',
              onRetry: () => setState(() {
                _future = _api.pointsRules();
              }),
            )
          else if (!snap.hasData)
            const OlLoadingCard()
          else ...[
            const OwWorkshopNote('poin & referral'),
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OlTextField(
                    label: 'Belanja per 1 poin (Rp)',
                    controller: _c['earn']!,
                    keyboardType: TextInputType.number,
                    helper: '0 = poin tidak diberikan',
                  ),
                  const SizedBox(height: OlSpace.md),
                  OlTextField(
                    label: 'Nilai 1 poin (Rp)',
                    controller: _c['value']!,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: OlSpace.md),
                  OlTextField(
                    label: 'Maks potongan dengan poin (%)',
                    controller: _c['max']!,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: OlSpace.md),
                  OlTextField(
                    label: 'Poin kedaluwarsa setelah (hari)',
                    controller: _c['expiry']!,
                    keyboardType: TextInputType.number,
                    helper: '0 = tidak kedaluwarsa',
                  ),
                ],
              ),
            ),
            const OlSectionHeader(title: 'Referral'),
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OlTextField(
                    label: 'Poin untuk pengajak',
                    controller: _c['referrer']!,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: OlSpace.md),
                  OlTextField(
                    label: 'Poin untuk pasien baru',
                    controller: _c['referee']!,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            if (earn > 0 && value > 0)
              Text(
                'Contoh: sesi ${Fmt.money(earn * 10)} → 10 poin = potongan ${Fmt.money(value * 10)} di kunjungan berikutnya.',
                style: t.caption.copyWith(color: c.muted),
              ),
          ],
        ],
      );
    },
  );
}
