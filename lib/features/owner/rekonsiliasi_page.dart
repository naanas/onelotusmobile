import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _State { match, diff, pending }

/// OW-19 Rekonsiliasi gateway (QRIS & VA): total sistem vs settlement per hari,
/// selisih yang perlu dicek.
class RekonsiliasiPage extends StatefulWidget {
  const RekonsiliasiPage({super.key});

  @override
  State<RekonsiliasiPage> createState() => _RekonsiliasiPageState();
}

class _RekonsiliasiPageState extends State<RekonsiliasiPage> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final days = <(String, String, _State)>[
      ('Sen, 5 Okt', '31 transaksi · MDR Rp13.200', _State.match),
      (
        'Sab, 3 Okt',
        _checked
            ? '28 transaksi · selisih dicek Sinta'
            : '28 transaksi · selisih Rp180.000',
        _checked ? _State.match : _State.diff,
      ),
      ('Jum, 2 Okt', '22 transaksi · MDR Rp9.800', _State.match),
      ('Sel, 6 Okt', 'Settlement H+1', _State.pending),
    ];

    Widget stat(String v, String l) => Expanded(
      child: OlCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        semanticLabel: '$l $v',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                v,
                style: t.mono.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(l, style: t.body.copyWith(fontSize: 14, color: c.muted)),
          ],
        ),
      ),
    );

    return OlDetailScaffold(
      title: 'Rekonsiliasi',
      context_: 'QRIS & VA · gateway pembayaran',
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              stat('Rp9,62 jt', 'sistem'),
              const SizedBox(width: 8),
              stat('Rp9,52 jt', 'settlement'),
              const SizedBox(width: 8),
              stat('Rp68rb', 'biaya MDR'),
            ],
          ),
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, (d, s, st)) in days.indexed)
                OlListItem(
                  title: d,
                  subtitle: s,
                  trailing: switch (st) {
                    _State.match => const OlTag('Cocok', tone: OlTagTone.ok),
                    _State.diff => const OlTag('Selisih', tone: OlTagTone.crit),
                    _State.pending => const OlTag(
                      'Belum settle',
                      tone: OlTagTone.muted,
                    ),
                  },
                  divider: i < days.length - 1,
                ),
            ],
          ),
        ),
        if (!_checked)
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Selisih 3 Okt', style: t.heading.copyWith(fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'QRIS Rp180.000 · Dewi Lestari',
                        style: t.body.copyWith(fontSize: 14.5),
                      ),
                    ),
                    const SizedBox(width: OlSpace.md),
                    Expanded(
                      child: Text(
                        'Lunas di sistem, tidak ada di settlement',
                        style: t.body.copyWith(fontSize: 14.5, color: c.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OlSpace.md),
                OlFootRow(
                  children: [
                    OlButton.secondary(
                      label: 'Lihat transaksi',
                      onPressed: () => context.push(Routes.kasirRiwayat),
                    ),
                    OlButton.secondary(
                      label: 'Tandai dicek',
                      onPressed: () async {
                        final feedback = context.feedback;
                        final res = await feedback.choose(
                          const ConfirmSpec(
                            title: 'Tandai selisih sudah dicek?',
                            message:
                                'Catatan tersimpan di audit log. Selisih tetap terlihat di laporan.',
                            confirmLabel: 'Tandai dicek',
                            danger: false,
                            reasonLabel: 'Catatan pemeriksaan',
                          ),
                        );
                        if (res.choice == ConfirmChoice.confirm && mounted) {
                          setState(() => _checked = true);
                          feedback.success('Selisih 3 Okt ditandai dicek.');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
