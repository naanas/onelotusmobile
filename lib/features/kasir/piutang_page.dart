import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-18 Piutang (tagihan belum lunas): pilih pasien → kirim link bayar massal / lunasi.
/// Pengingat sejenis maksimal 1 kali per 7 hari per pasien.
class PiutangPage extends StatefulWidget {
  const PiutangPage({super.key});

  @override
  State<PiutangPage> createState() => _PiutangPageState();
}

class _PiutangPageState extends State<PiutangPage> {
  final _rows = [
    ('Hendra Gunawan', 'Sisa dari Rp400.000 · diingatkan 1 Okt', 300000, 12),
    ('Wulan Sari', 'Home visit · belum diingatkan', 190000, 8),
    ('Arief Nugroho', 'Link bayar terkirim kemarin', 150000, 2),
  ];
  final _picked = <int>{0, 1};

  Future<void> _send() async {
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: 'Kirim link bayar ke ${_picked.length} pasien?',
        message:
            'Contoh pesan: "Halo Kak, berikut link pembayaran sisa tagihan One Lotus…"',
        confirmLabel: 'Kirim ke ${_picked.length} pasien',
        danger: false,
      ),
    );
    if (ok && mounted) {
      context.feedback.success(
        'Link bayar terkirim ke ${_picked.length} pasien.',
      );
      setState(_picked.clear);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final total = _rows.fold(0, (s, r) => s + r.$3);
    return OlDetailScaffold(
      title: 'Tagihan belum lunas',
      foot: [
        OlFootRow(
          children: [
            OlButton.secondary(
              label: 'Lunasi',
              onPressed: _picked.length == 1
                  ? () => context.feedback.info('Membuka pembayaran…')
                  : null,
            ),
            OlButton(
              label: 'Kirim link bayar (${_picked.length})',
              onPressed: _picked.isEmpty ? null : _send,
            ),
          ],
        ),
      ],
      children: [
        OlCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total piutang',
                      style: t.body.copyWith(color: c.muted),
                    ),
                    Text(
                      Fmt.money(total),
                      style: t.mono.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_rows.length} pasien',
                style: t.body.copyWith(color: c.muted),
              ),
            ],
          ),
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(
            horizontal: OlSpace.lg,
            vertical: 4,
          ),
          child: Column(
            children: [
              for (final (i, (name, note, amount, days)) in _rows.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: i < _rows.length - 1
                        ? Border(bottom: BorderSide(color: c.line))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OlCheckbox(
                          label: name,
                          subtitle: note,
                          value: _picked.contains(i),
                          onChanged: (v) => setState(
                            () => v ? _picked.add(i) : _picked.remove(i),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Fmt.money(amount),
                            style: t.mono.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          OlTag(
                            '$days hari',
                            tone: days > 7 ? OlTagTone.crit : OlTagTone.warn,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Text(
          'Pengingat sejenis maksimal 1 kali per 7 hari per pasien.',
          style: t.body.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
