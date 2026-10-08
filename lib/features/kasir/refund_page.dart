import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-14 Refund / batal transaksi (§6.4.6): item → alasan → metode → dampak otomatis → konfirmasi.
/// Di atas batas tertentu perlu persetujuan owner (batas: workshop §16 no. 9).
class RefundPage extends StatefulWidget {
  const RefundPage({super.key});

  @override
  State<RefundPage> createState() => _RefundPageState();
}

class _RefundPageState extends State<RefundPage> {
  String _type = 'partial';
  final _items = {
    'Adjustment Therapy': (250000, false),
    'Tambahan cedera': (100000, true),
  };
  String _reason = 'Salah input item';
  String _method = 'cash';
  final _note = TextEditingController(text: 'Tambahan cedera tidak dilakukan.');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Nilai kembali setelah diskon member 10% (contoh mockup).
  int get _amount {
    if (_type == 'full') return 450000;
    final gross = _items.values.where((v) => v.$2).fold(0, (s, v) => s + v.$1);
    return (gross * 0.9).round();
  }

  Future<void> _submit() async {
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: 'Refund ${Fmt.money(_amount)} ke Andi Pratama?',
        message:
            'Komisi terapis, poin, dan laporan omzet ikut disesuaikan. Tindakan ini tercatat di audit log.',
        confirmLabel: 'Proses refund',
      ),
    );
    if (!ok || !mounted) return;
    context.feedback.success(
      _amount > 200000
          ? 'Refund diajukan. Menunggu persetujuan owner.'
          : 'Refund diproses.',
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget req(String text) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          TextSpan(
            text: ' *',
            style: TextStyle(color: c.crit),
          ),
        ],
      ),
      style: t.fieldLabel,
    );
    final points = (_amount / 10000).round();

    return OlDetailScaffold(
      title: 'Ajukan refund',
      context_: 'STR-PST-02841 · Andi Pratama · Rp450.000',
      foot: [
        OlButton(
          label: 'Proses refund ${Fmt.money(_amount)}',
          variant: OlButtonVariant.danger,
          onPressed: _amount == 0 ? null : _submit,
        ),
      ],
      children: [
        req('Jenis'),
        OlSegmented<String>(
          segments: const {'full': 'Penuh', 'partial': 'Sebagian'},
          value: _type,
          onChanged: (v) => setState(() => _type = v),
        ),
        if (_type == 'partial') ...[
          req('Item yang dikembalikan'),
          OlCard(
            padding: const EdgeInsets.symmetric(
              horizontal: OlSpace.lg,
              vertical: 4,
            ),
            child: Column(
              children: [
                for (final (i, e) in _items.entries.indexed)
                  Container(
                    decoration: BoxDecoration(
                      border: i < _items.length - 1
                          ? Border(bottom: BorderSide(color: c.line))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OlCheckbox(
                            label: e.key,
                            value: e.value.$2,
                            onChanged: (v) =>
                                setState(() => _items[e.key] = (e.value.$1, v)),
                          ),
                        ),
                        Text(
                          Fmt.money(e.value.$1),
                          style: t.mono.copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        req('Alasan'),
        Wrap(
          spacing: 8,
          children: [
            for (final r in const [
              'Salah input item',
              'Layanan tidak jadi',
              'Keluhan pasien',
              'Lainnya',
            ])
              OlChip(
                label: r,
                selected: _reason == r,
                onTap: () => setState(() => _reason = r),
              ),
          ],
        ),
        OlTextField(label: '', controller: _note, maxLines: 3),
        req('Metode pengembalian'),
        OlSegmented<String>(
          segments: const {'cash': 'Tunai', 'transfer': 'Transfer'},
          value: _method,
          onChanged: (v) => setState(() => _method = v),
        ),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: c.brandSoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Dampak otomatis', style: t.heading),
              const SizedBox(height: 6),
              OlInfoRow(
                label: 'Omzet hari ini',
                value: '-${Fmt.money(_amount)}',
                valueStyle: t.mono.copyWith(fontSize: 15),
              ),
              OlInfoRow(
                label: 'Komisi Dimas',
                value: '-${Fmt.money((_amount / 6).round() ~/ 1000 * 1000)}',
                valueStyle: t.mono.copyWith(fontSize: 15),
              ),
              OlInfoRow(
                label: 'Poin pasien',
                value: '-$points poin',
                valueStyle: t.mono.copyWith(fontSize: 15),
              ),
              OlInfoRow(
                label: 'Kuota paket',
                value: 'Tidak berubah',
                valueStyle: t.body.copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
        OlMoneyTotal(label: 'Dikembalikan', amount: _amount),
        Text(
          'Setelah diskon member 10%. Di atas Rp200.000 perlu persetujuan owner.',
          style: t.body.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
