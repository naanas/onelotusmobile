import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

class _Row {
  _Row(this.name, this.detail, this.amount, {this.approved = false});
  final String name;
  final String detail;
  final String amount;
  bool approved;
}

/// OW-07 Rekap komisi per bulan. Angka hanya contoh: aturan komisi menunggu
/// workshop mitra (spec §16) — layar ini tidak menghitung apa pun.
class RekapKomisiPage extends StatefulWidget {
  const RekapKomisiPage({super.key});

  @override
  State<RekapKomisiPage> createState() => _RekapKomisiPageState();
}

class _RekapKomisiPageState extends State<RekapKomisiPage> {
  int _month = 9;
  final _rows = {
    9: [
      _Row(
        'Dimas',
        '92 sesi · 14 home visit · koreksi −Rp45.000',
        'Rp5,42 jt',
        approved: true,
      ),
      _Row('Fajar', '78 sesi · 9 home visit', 'Rp4,76 jt'),
      _Row('Laras', '64 sesi · 6 home visit', 'Rp4,10 jt'),
    ],
    10: [
      _Row('Dimas', '24 sesi · 3 home visit', 'Rp1,38 jt'),
      _Row('Fajar', '21 sesi · 2 home visit', 'Rp1,20 jt'),
      _Row('Laras', '17 sesi · 1 home visit', 'Rp0,98 jt'),
    ],
  };

  Future<void> _approveAll(List<_Row> pending) async {
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: 'Setujui ${pending.length} komisi?',
        message:
            'Komisi ${pending.map((r) => r.name).join(' & ')} untuk September dikunci. '
            'Perubahan aturan setelah ini tidak mengubah angkanya.',
        confirmLabel: 'Setujui',
        danger: false,
      ),
    );
    if (!ok || !mounted) return;
    setState(() {
      for (final r in pending) {
        r.approved = true;
      }
    });
    context.feedback.success('Komisi disetujui. Terapis diberi tahu.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final rows = _rows[_month]!;
    final running = _month == 10;
    final pending = running
        ? <_Row>[]
        : rows.where((r) => !r.approved).toList();
    final monthName = running ? 'Oktober' : 'September';

    return OlDetailScaffold(
      title: 'Rekap komisi',
      foot: [
        OlFootRow(
          children: [
            OlButton.secondary(
              label: 'Ekspor',
              onPressed: () => context.feedback.info(
                'File komisi $monthName dibuat & tercatat di audit log.',
              ),
            ),
            OlButton(
              label: pending.isEmpty
                  ? 'Semua disetujui'
                  : 'Setujui semua (${pending.length})',
              onPressed: pending.isEmpty ? null : () => _approveAll(pending),
            ),
          ],
        ),
      ],
      children: [
        OlSegmented<int>(
          segments: const {9: 'September', 10: 'Oktober'},
          value: _month,
          onChanged: (v) => setState(() => _month = v),
        ),
        OlCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      running
                          ? 'Estimasi komisi Oktober'
                          : 'Total komisi September',
                      style: t.body.copyWith(color: c.muted),
                    ),
                    Text(
                      running ? 'Rp3.560.000' : 'Rp14.280.000',
                      style: t.mono.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (running)
                const OlTag('Berjalan', tone: OlTagTone.muted)
              else if (pending.isNotEmpty)
                OlTag('${pending.length} belum disetujui', tone: OlTagTone.warn)
              else
                const OlTag('Disetujui', tone: OlTagTone.ok),
            ],
          ),
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, r) in rows.indexed)
                OlListItem(
                  leading: OlAvatar(name: r.name),
                  title: r.name,
                  subtitle: r.detail,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        r.amount,
                        style: t.mono.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      r.approved
                          ? const OlTag('Disetujui', tone: OlTagTone.ok)
                          : const OlTag('Estimasi', tone: OlTagTone.muted),
                    ],
                  ),
                  divider: i < rows.length - 1,
                  onTap: () => context.feedback.sheet<void>(
                    title: 'Komisi ${r.name} · $monthName',
                    message:
                        '${r.detail}\n\nRincian per sesi tersedia setelah aturan komisi ditetapkan bersama mitra.',
                    actions: const [
                      SheetAction(
                        'Tutup',
                        null,
                        variant: OlButtonVariant.secondary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Text(
          'Ketuk terapis untuk rincian per sesi. Komisi yang sudah disetujui tidak berubah bila aturan komisi diganti.',
          style: t.body.copyWith(fontSize: 14, color: c.muted),
        ),
      ],
    );
  }
}
