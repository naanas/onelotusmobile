import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Segment { away, packageLow, unpaid }

enum _Tpl { greet, control, promo }

class _Recipient {
  _Recipient(this.name, this.detail, {this.selected = true})
    : initial = selected;
  final String name;
  final String detail;
  final bool initial;
  bool selected;
}

/// OW-20 Kirim pengingat massal (WhatsApp): segmen, template, pratinjau,
/// daftar penerima. Pasien yang menolak promo otomatis dikecualikan;
/// pengingat sejenis maks 1×/7 hari per pasien.
class PengingatPage extends StatefulWidget {
  const PengingatPage({super.key});

  @override
  State<PengingatPage> createState() => _PengingatPageState();
}

class _PengingatPageState extends State<PengingatPage> {
  _Segment _segment = _Segment.away;
  _Tpl _tpl = _Tpl.greet;

  // Contoh beberapa penerima teratas; total (yang tercentang awal) dari mockup.
  static const _totals = {
    _Segment.away: 14,
    _Segment.packageLow: 6,
    _Segment.unpaid: 2,
  };
  final _recipients = {
    _Segment.away: [
      _Recipient('Lestari Kusuma', 'Terakhir 18 Agu · bahu kiri'),
      _Recipient('Nur Wahyuni', 'Terakhir 11 Agu · leher'),
      _Recipient(
        'Bayu Pradana',
        'Diingatkan 4 hari lalu · dilewati',
        selected: false,
      ),
    ],
    _Segment.packageLow: [
      _Recipient('Rina Setiawati', 'Cedera Ringan 5× · sisa 1 sesi'),
      _Recipient('Hendra Gunawan', 'Adjustment 5× · sisa 1 sesi'),
    ],
    _Segment.unpaid: [
      _Recipient('Hendra Gunawan', 'Sisa Rp300.000 · 12 hari'),
      _Recipient('Wulan Sari', 'Rp190.000 · 8 hari'),
      _Recipient(
        'Arief Nugroho',
        'Link bayar terkirim kemarin',
        selected: false,
      ),
    ],
  };

  String get _preview => switch (_tpl) {
    _Tpl.greet =>
      'Halo Lestari, sudah 7 minggu sejak terapi bahu terakhir Anda. Bagaimana kabarnya? Booking sesi kontrol di sini: onelotus.id/b/…',
    _Tpl.control =>
      'Halo Lestari, waktunya kontrol bahu kiri. Pilih jadwal yang cocok: onelotus.id/b/…',
    _Tpl.promo =>
      'Halo Lestari, ada potongan 10% untuk sesi kontrol bulan ini. Booking: onelotus.id/b/…',
  };

  int get _count {
    var n = _totals[_segment]!;
    for (final r in _recipients[_segment]!) {
      if (r.selected != r.initial) n += r.selected ? 1 : -1;
    }
    return n;
  }

  Future<void> _send() async {
    final n = _count;
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: 'Kirim WhatsApp ke $n pasien?',
        message:
            'Pesan dikirim bertahap dari nomor klinik. Pasien yang sudah diingatkan 7 hari terakhir dilewati.',
        confirmLabel: 'Kirim',
        danger: false,
      ),
    );
    if (ok && mounted) {
      context.feedback.success(
        'Terkirim ke $n pasien. Status per pasien di notifikasi.',
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final list = _recipients[_segment]!;
    final n = _count;

    return OlDetailScaffold(
      title: 'Kirim pengingat',
      foot: [
        OlButton(label: 'Kirim ke $n pasien', onPressed: n > 0 ? _send : null),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Segmen', style: t.fieldLabel),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (s, l) in const [
                  (_Segment.away, 'Belum kembali >30 hari'),
                  (_Segment.packageLow, 'Paket hampir habis'),
                  (_Segment.unpaid, 'Belum lunas'),
                ])
                  OlChip(
                    label: l,
                    selected: _segment == s,
                    onTap: () => setState(() => _segment = s),
                  ),
              ],
            ),
          ],
        ),
        OlSelectField<_Tpl>(
          label: 'Template',
          sheetTitle: 'Pilih template',
          value: _tpl,
          options: const {
            _Tpl.greet: 'Sapaan pasien lama',
            _Tpl.control: 'Ajak kontrol',
            _Tpl.promo: 'Promo kontrol',
          },
          onChanged: (v) => setState(() => _tpl = v),
        ),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F0EA),
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _preview,
              semanticsLabel: 'Pratinjau pesan: $_preview',
              style: t.body.copyWith(fontSize: 14.5),
            ),
          ),
        ),
        Row(
          children: [
            Text('Penerima · $n', style: t.heading.copyWith(fontSize: 17)),
            const SizedBox(width: OlSpace.sm),
            Expanded(
              child: Text(
                '2 dikecualikan (menolak promo)',
                textAlign: TextAlign.right,
                style: t.body.copyWith(fontSize: 13.5, color: c.muted),
              ),
            ),
          ],
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, r) in list.indexed)
                Container(
                  decoration: BoxDecoration(
                    border: i < list.length - 1
                        ? Border(bottom: BorderSide(color: c.line))
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: OlCheckbox(
                    label: r.name,
                    subtitle: r.detail,
                    value: r.selected,
                    onChanged: (v) => setState(() => r.selected = v),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
