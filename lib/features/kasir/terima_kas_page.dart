import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-16 Terima kas terapis (home visit, §6.4.7): hitung fisik vs tercatat sistem.
class TerimaKasPage extends StatefulWidget {
  const TerimaKasPage({super.key});

  @override
  State<TerimaKasPage> createState() => _TerimaKasPageState();
}

class _TerimaKasPageState extends State<TerimaKasPage> {
  static const _system = 445000;
  int _physical = 445000;

  Future<void> _accept({bool withDiff = false}) async {
    if (withDiff) {
      final r = await context.feedback.choose(
        ConfirmSpec(
          title:
              'Terima dengan selisih ${Fmt.money((_physical - _system).abs())}?',
          message: 'Owner otomatis diberi tahu.',
          confirmLabel: 'Terima dengan selisih',
          danger: false,
          reasonLabel: 'Catatan selisih',
        ),
      );
      if (!r.confirmed) return;
    }
    if (!mounted) return;
    context.feedback.success('Kas Dimas diterima ${Fmt.money(_physical)}.');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final diff = _physical - _system;
    return OlDetailScaffold(
      title: 'Terima kas terapis',
      foot: [
        OlButton(
          label: 'Terima ${Fmt.money(_physical)}',
          onPressed: diff == 0 ? () => _accept() : null,
        ),
        OlButton.text(
          label: 'Terima dengan selisih',
          expand: true,
          onPressed: () => _accept(withDiff: true),
        ),
      ],
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const OlAvatar(name: 'Dimas'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dimas', style: t.heading.copyWith(fontSize: 17)),
                        Text(
                          'Diserahkan 17.42 · 2 home visit',
                          style: t.body.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  const OlTag('Menunggu', tone: OlTagTone.warn),
                ],
              ),
              const Divider(height: 22),
              const OlMoneyRow(label: 'Budi Hartono · 14.36', amount: 295000),
              const OlMoneyRow(label: 'Wawan Hidayat · 17.10', amount: 150000),
              const OlMoneyTotal(label: 'Tercatat sistem', amount: _system),
            ],
          ),
        ),
        OlMoneyField(
          label: 'Jumlah fisik diterima',
          isRequired: true,
          value: _physical,
          onChanged: (v) => setState(() => _physical = v),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: diff == 0
              ? const SyncIndicator(
                  status: SyncSynced(),
                  label: 'Cocok · tanpa selisih',
                )
              : SyncIndicator(
                  status: const SyncFailed(1),
                  label:
                      'Selisih ${diff > 0 ? '+' : '-'}${Fmt.money(diff.abs())}',
                ),
        ),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: c.brandSoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bila ada selisih',
                style: t.bodyStrong.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih "Terima dengan selisih", tulis catatan, dan owner otomatis diberi tahu.',
                style: t.body.copyWith(color: c.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
