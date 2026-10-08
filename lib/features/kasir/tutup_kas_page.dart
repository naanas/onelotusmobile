import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-17 Tutup kas harian: sistem vs dihitung per metode, selisih wajib catatan,
/// QRIS yang masih menunggu harus diselesaikan dulu. Setelah ditutup, transaksi hari itu terkunci.
class TutupKasPage extends StatefulWidget {
  const TutupKasPage({super.key});

  @override
  State<TutupKasPage> createState() => _TutupKasPageState();
}

class _TutupKasPageState extends State<TutupKasPage> {
  static const _systemCash = 1235000;
  int _physical = 1230000;
  final _note = TextEditingController();
  bool _qrisPending = true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int get _diff => _physical - _systemCash;
  bool get _canClose =>
      !_qrisPending && (_diff == 0 || _note.text.trim().isNotEmpty);

  Future<void> _close() async {
    final ok = await context.feedback.confirm(
      const ConfirmSpec(
        title: 'Tutup kas hari ini?',
        message:
            'Transaksi Sel, 6 Okt terkunci. Koreksi setelah ini hanya oleh owner sebagai transaksi hari berjalan.',
        confirmLabel: 'Tutup kas',
        danger: false,
      ),
    );
    if (ok && mounted) {
      context.feedback.success('Kas ditutup & dikirim ke owner.');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final head = t.overline;
    Widget cell(
      String s, {
      TextStyle? style,
      TextAlign align = TextAlign.right,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(s, textAlign: align, style: style),
    );
    TableRow row(
      String m,
      String sys,
      String counted, {
      bool auto = false,
      bool bold = false,
    }) => TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      children: [
        cell(m, style: t.body.copyWith(fontSize: 14.5), align: TextAlign.left),
        cell(sys, style: t.mono.copyWith(fontSize: 14)),
        cell(
          counted,
          style: auto
              ? t.body.copyWith(color: c.muted)
              : t.mono.copyWith(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w700 : null,
                ),
        ),
      ],
    );
    final hasDiff = _diff != 0;

    return OlDetailScaffold(
      title: 'Tutup kas',
      context_: 'Sel, 6 Okt · Klinik Pusat · Sinta',
      foot: [
        OlButton(
          label: 'Tutup kas & kirim ke owner',
          onPressed: _canClose ? _close : null,
        ),
      ],
      children: [
        OlCard(
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.1),
              2: FlexColumnWidth(1.1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.line)),
                ),
                children: [
                  cell('METODE', style: head, align: TextAlign.left),
                  cell('SISTEM', style: head),
                  cell('DIHITUNG', style: head),
                ],
              ),
              row(
                'Tunai klinik',
                Fmt.money(_systemCash),
                Fmt.money(_physical),
                bold: true,
              ),
              row('Kas terapis', 'Rp445.000', 'Diterima'),
              row('QRIS', 'Rp860.000', 'otomatis', auto: true),
              row('Transfer / VA', 'Rp1.150.000', 'otomatis', auto: true),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: hasDiff ? c.critSoft : c.okSoft,
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDiff ? 'Selisih tunai' : 'Tunai cocok',
                      style: t.heading.copyWith(color: hasDiff ? c.crit : c.ok),
                    ),
                    if (hasDiff)
                      Text(
                        'Wajib isi catatan',
                        style: t.body.copyWith(color: c.crit),
                      ),
                  ],
                ),
              ),
              Text(
                '${_diff < 0 ? '-' : (_diff > 0 ? '+' : '')}${Fmt.money(_diff.abs())}',
                style: t.mono.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: hasDiff ? c.crit : c.ok,
                ),
              ),
            ],
          ),
        ),
        OlMoneyField(
          label: 'Uang tunai fisik',
          isRequired: true,
          large: false,
          value: _physical,
          onChanged: (v) => setState(() => _physical = v),
        ),
        if (hasDiff)
          OlTextField(
            label: 'Catatan selisih',
            isRequired: true,
            controller: _note,
            maxLines: 3,
            error: _note.text.trim().isEmpty
                ? 'Tulis penyebab selisih sebelum menutup kas.'
                : null,
            onChanged: (_) => setState(() {}),
          ),
        if (_qrisPending)
          OlBanner(
            tone: OlBannerTone.warn,
            message:
                '1 QRIS masih menunggu (Dewi Lestari Rp180.000). Selesaikan atau batalkan dulu.',
            actionLabel: 'Batalkan',
            onAction: () => setState(() => _qrisPending = false),
          ),
      ],
    );
  }
}
