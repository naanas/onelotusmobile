import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

/// PS-10 Jadwal saya: mendatang (lokasi, persiapan, ubah/kalender/arah) & riwayat.
class JadwalSayaPage extends StatefulWidget {
  const JadwalSayaPage({super.key});

  @override
  State<JadwalSayaPage> createState() => _JadwalSayaPageState();
}

class _JadwalSayaPageState extends State<JadwalSayaPage> {
  bool _history = false;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    TextSpan when(String day, String time) => TextSpan(
      text: '$day · ',
      children: [
        TextSpan(
          text: time,
          style: t.mono.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    );

    return OlDetailScaffold(
      title: 'Jadwal saya',
      children: [
        OlSegmented<bool>(
          segments: const {false: 'Mendatang', true: 'Riwayat'},
          value: _history,
          onChanged: (v) => setState(() => _history = v),
        ),
        if (!_history) ...[
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const OlTag('Dijadwalkan', tone: OlTagTone.outline),
                    const Spacer(),
                    Text('2 hari lagi', style: t.body.copyWith(color: c.muted)),
                  ],
                ),
                const SizedBox(height: 10),
                Text.rich(
                  when('Kamis, 8 Okt', '16.00'),
                  style: t.heading.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  'Masase cedera ringan · 45 mnt · Dimas',
                  style: t.body.copyWith(fontSize: 14.5, color: c.muted),
                ),
                const SizedBox(height: OlSpace.md),
                const OlPinMap(
                  height: 96,
                  semanticLabel: 'Lokasi Klinik Pusat Malang',
                ),
                const SizedBox(height: OlSpace.md),
                Text(
                  'Klinik Pusat Malang · Jl. Soekarno-Hatta No. 9',
                  style: t.body.copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Persiapan: pakai celana pendek atau longgar, datang 10 menit lebih awal.',
                  style: t.body.copyWith(fontSize: 14, color: c.muted),
                ),
                const SizedBox(height: OlSpace.md),
                Row(
                  children: [
                    for (final (i, (l, onTap)) in [
                      ('Ubah', () => context.push(PRoutes.ubahJadwal)),
                      (
                        'Kalender',
                        () => context.feedback.success(
                          'Ditambahkan ke kalender HP.',
                        ),
                      ),
                      ('Arah', () => context.feedback.info('Membuka peta…')),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: OlButton.secondary(
                          label: l,
                          small: true,
                          onPressed: onTap,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: OlTag(
                        'Menunggu konfirmasi',
                        tone: OlTagTone.muted,
                      ),
                    ),
                    const SizedBox(width: OlSpace.sm),
                    const Spacer(),
                    Text(
                      'dikirim 06.40',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text.rich(
                  when('Kamis, 15 Okt', '16.00'),
                  style: t.heading.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Masase cedera ringan · paket baru',
                  style: t.body.copyWith(fontSize: 14.5, color: c.muted),
                ),
              ],
            ),
          ),
        ] else
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, (d, s, tag)) in const [
                  ('Sel, 6 Okt · 10.30', 'Masase cedera · Dimas', 'Selesai'),
                  (
                    'Sel, 29 Sep · 16.00',
                    'Masase + kinesio tape · Dimas',
                    'Selesai',
                  ),
                  (
                    'Sel, 22 Sep · 09.00',
                    'Adjustment ankle · Fajar',
                    'Selesai',
                  ),
                  (
                    'Sen, 15 Sep · 15.00',
                    'Masase cedera · Dimas',
                    'Dibatalkan',
                  ),
                ].indexed)
                  OlListItem(
                    title: d,
                    subtitle: s,
                    trailing: OlTag(
                      tag,
                      tone: tag == 'Selesai' ? OlTagTone.ok : OlTagTone.strike,
                    ),
                    divider: i < 3,
                    onTap: tag == 'Selesai'
                        ? () => context.push(PRoutes.riwayat)
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
