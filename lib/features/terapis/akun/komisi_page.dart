import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

/// TR-12 Komisi saya: estimasi sampai disetujui owner. Nama pasien disingkat,
/// nominal yang dibayar pasien tidak ditampilkan. Angka = contoh mockup
/// (aturan komisi menunggu workshop §16 no. 2).
class KomisiPage extends StatefulWidget {
  const KomisiPage({super.key});

  @override
  State<KomisiPage> createState() => _KomisiPageState();
}

class _KomisiPageState extends State<KomisiPage> {
  String _month = 'okt';

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final oct = _month == 'okt';
    Widget stat(String value, String label, {bool crit = false}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: t.heading.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: crit ? c.crit : c.fg,
            ),
          ),
          Text(label, style: t.body.copyWith(color: c.muted)),
        ],
      ),
    );
    Widget row(
      String date,
      String title,
      String sub,
      String amount, {
      bool minus = false,
      bool divider = true,
    }) => Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(date, style: t.mono.copyWith(fontSize: 14)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(sub, style: t.body.copyWith(color: c.muted)),
              ],
            ),
          ),
          Text(
            amount,
            style: t.mono.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: minus ? c.crit : c.fg,
            ),
          ),
        ],
      ),
    );

    return OlDetailScaffold(
      title: 'Komisi saya',
      children: [
        OlSegmented<String>(
          segments: const {'sep': 'September', 'okt': 'Oktober'},
          value: _month,
          onChanged: (v) => setState(() => _month = v),
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      oct ? 'Estimasi komisi 1–6 Okt' : 'Komisi September',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ),
                  OlTag(
                    oct ? 'Estimasi' : 'Disetujui',
                    tone: oct ? OlTagTone.muted : OlTagTone.ok,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                oct ? 'Rp1.284.000' : 'Rp5.912.500',
                style: t.mono.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  stat(oct ? '24' : '102', 'sesi'),
                  stat(oct ? '5' : '18', 'home visit'),
                  stat(oct ? '-1' : '0', 'koreksi refund', crit: oct),
                ],
              ),
            ],
          ),
        ),
        const OlOverline('Rincian per sesi'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              row('6 Okt', 'R.S. · Masase cedera', 'Paket', 'Rp45.000'),
              row(
                '5 Okt',
                'B.H. · Home visit',
                'Relaksasi + transport',
                'Rp90.000',
              ),
              row('5 Okt', 'D.L. · Adjustment', 'Per sesi', 'Rp62.500'),
              row(
                '3 Okt',
                'I.R. · Refund sesi',
                'Koreksi otomatis',
                '-Rp45.000',
                minus: true,
                divider: false,
              ),
            ],
          ),
        ),
        Text(
          'Nama pasien disingkat. Nominal yang dibayar pasien tidak ditampilkan — hanya komisi. Angka final setelah disetujui owner.',
          style: t.body.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
