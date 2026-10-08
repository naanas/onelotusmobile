import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// OW-13 Poin Lotus & referral. Semua angka diisi owner; nilai awal hanya
/// contoh mockup (aturan poin final menunggu workshop mitra, spec §16).
class PoinPage extends StatefulWidget {
  const PoinPage({super.key});

  @override
  State<PoinPage> createState() => _PoinPageState();
}

class _PoinPageState extends State<PoinPage> {
  int _perTenK = 1;
  int _pointValue = 100;
  int _maxPct = 20;
  int _months = 12;
  int _inviter = 200;
  int _friend = 50000;
  final _terms = TextEditingController(text: 'Transaksi pertama teman lunas');

  @override
  void dispose() {
    _terms.dispose();
    super.dispose();
  }

  Widget _num(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    String? suffix,
  }) => OlTextField(
    label: label,
    initialValue: '$value',
    mono: true,
    suffixText: suffix,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: (v) => setState(() => onChanged(int.tryParse(v) ?? 0)),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    const pay = 450000;
    final earned = pay ~/ 10000 * _perTenK;
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: OlSpace.md),
        Expanded(child: b),
      ],
    );

    return OlDetailScaffold(
      title: 'Poin Lotus & referral',
      foot: [
        OlButton(
          label: 'Simpan aturan',
          onPressed: () => context.feedback.success(
            'Aturan poin disimpan. Berlaku untuk transaksi berikutnya.',
          ),
        ),
      ],
      children: [
        const OlOverline('POIN'),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pair(
                _num('Poin per Rp10.000', _perTenK, (v) => _perTenK = v),
                OlMoneyField(
                  label: 'Nilai 1 poin',
                  large: false,
                  value: _pointValue,
                  onChanged: (v) => setState(() => _pointValue = v),
                ),
              ),
              const SizedBox(height: OlSpace.md),
              pair(
                _num(
                  'Maks pakai / transaksi',
                  _maxPct,
                  (v) => _maxPct = v,
                  suffix: '%',
                ),
                _num(
                  'Masa berlaku',
                  _months,
                  (v) => _months = v,
                  suffix: 'bulan',
                ),
              ),
              const SizedBox(height: OlSpace.md),
              Text(
                'Contoh: bayar ${Fmt.money(pay)} → +$earned poin = ${Fmt.money(earned * _pointValue)}.',
                style: t.body.copyWith(fontSize: 14, color: c.muted),
              ),
            ],
          ),
        ),
        const OlOverline('REFERRAL'),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pair(
                _num(
                  'Hadiah pengundang',
                  _inviter,
                  (v) => _inviter = v,
                  suffix: 'poin',
                ),
                OlMoneyField(
                  label: 'Hadiah teman baru',
                  large: false,
                  value: _friend,
                  onChanged: (v) => setState(() => _friend = v),
                ),
              ),
              const SizedBox(height: OlSpace.md),
              OlTextField(label: 'Syarat', controller: _terms),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: c.goldSoft,
            borderRadius: BorderRadius.circular(OlRadius.card),
            border: Border.all(color: c.gold.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bulan ini', style: t.body.copyWith(color: c.warn)),
              const SizedBox(height: 2),
              Text(
                '38.240 poin beredar · 9 referral berhasil',
                style: t.bodyStrong.copyWith(fontSize: 16, color: c.warn),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
