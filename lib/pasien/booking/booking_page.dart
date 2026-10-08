import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

const _services = [
  ('Masase cedera ringan', 45, 150000),
  ('Adjustment Therapy', 60, 250000),
  ('Relaksasi Premium', 90, 300000),
];

const _days = [
  OlDay('Sel', 6),
  OlDay('Rab', 7),
  OlDay('Kam', 8),
  OlDay('Jum', 9),
  OlDay('Sab', 10),
  OlDay('Min', 11, closed: true),
  OlDay('Sen', 12),
];

const _dayNames = {
  6: 'Selasa',
  7: 'Rabu',
  8: 'Kamis',
  9: 'Jumat',
  10: 'Sabtu',
  12: 'Senin',
};

/// PS-08 Booking (tab Booking): layanan → lokasi & terapis → waktu + ringkasan
/// → terkirim, menunggu konfirmasi front desk (§5.13).
class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int _step = 0;
  int _service = 0;
  bool _homeVisit = false;
  String _therapist = 'Dimas';
  int _day = 8;
  String? _slot = '16.00';
  bool _sending = false;

  // Pasien punya paket Cedera Ringan 5× (sisa 1) — hanya untuk layanan itu.
  bool get _usesPackage => _service == 0 && !_homeVisit;

  void _reset() => setState(() {
    _step = 0;
    _slot = null;
  });

  Future<void> _send() async {
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _sending = false;
      _step = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final (name, minutes, price) = _services[_service];

    if (_step == 3) {
      return OlMessageScreen(
        illustration: OlIllustration.onboardBooking,
        title: 'Booking terkirim',
        message:
            '${_dayNames[_day]}, $_day Okt · $_slot · $name. Status "Menunggu konfirmasi" sampai diterima front desk — Anda akan menerima notifikasi.',
        foot: [
          OlButton(
            label: 'Lihat jadwal saya',
            onPressed: () {
              context.push(PRoutes.jadwal);
              _reset();
            },
          ),
          OlButton.text(label: 'Booking lagi', expand: true, onPressed: _reset),
        ],
      );
    }

    final stepTitle = const [
      'Pilih layanan',
      'Lokasi & terapis',
      'Pilih waktu',
    ];
    final foot = switch (_step) {
      2 => OlButton(
        label: 'Kirim booking',
        loading: _sending,
        onPressed: _slot == null ? null : _send,
      ),
      _ => OlButton(label: 'Lanjut', onPressed: () => setState(() => _step++)),
    };

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: OlDetailScaffold(
        title: 'Booking sesi',
        showBack: _step > 0,
        top: OlStepProgress(count: 4, current: _step),
        context_: 'Langkah ${_step + 1} dari 4 · ${stepTitle[_step]}',
        foot: [foot],
        children: switch (_step) {
          0 => [
            for (final (i, (n, m, p)) in _services.indexed)
              OlChoiceCard(
                title: n,
                subtitle:
                    '$m mnt · ${Fmt.money(p)}${i == 0 ? ' · bisa pakai paket Anda' : ''}',
                radio: true,
                selected: _service == i,
                onTap: () => setState(() => _service = i),
              ),
          ],
          1 => [
            const OlOverline('LOKASI'),
            OlChoiceCard(
              title: 'Klinik Pusat Malang',
              subtitle: 'Jl. Soekarno-Hatta No. 9, Lowokwaru',
              radio: true,
              selected: !_homeVisit,
              onTap: () => setState(() => _homeVisit = false),
            ),
            OlChoiceCard(
              title: 'Home visit · Rumah',
              subtitle: 'Jl. Bunga Kopi No. 14, Lowokwaru · 3,1 km',
              radio: true,
              selected: _homeVisit,
              onTap: () => setState(() => _homeVisit = true),
            ),
            OlButton.text(
              label: 'Kelola alamat tersimpan',
              onPressed: () => context.push(PRoutes.alamat),
            ),
            const OlOverline('TERAPIS (OPSIONAL)'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final th in const [
                  'Dimas',
                  'Laras',
                  'Fajar',
                  'Siapa saja',
                ])
                  OlChip(
                    label: th == 'Dimas' ? 'Dimas · pernah menangani' : th,
                    selected: _therapist == th,
                    onTap: () => setState(() => _therapist = th),
                  ),
              ],
            ),
          ],
          _ => [
            OlCard(
              child: Column(
                children: [
                  OlInfoRow(label: 'Layanan', value: '$name · $minutes mnt'),
                  OlInfoRow(
                    label: 'Lokasi',
                    value: _homeVisit
                        ? 'Home visit · Rumah'
                        : 'Klinik Pusat Malang',
                  ),
                  OlInfoRow(
                    label: 'Terapis',
                    value: _therapist == 'Dimas'
                        ? 'Dimas (pernah menangani)'
                        : _therapist,
                  ),
                ],
              ),
            ),
            OlDayStrip(
              days: _days,
              selected: _day,
              onSelect: (d) => setState(() {
                _day = d;
                _slot = null;
              }),
            ),
            const OlOverline('PAGI'),
            OlSlotPicker(
              slots: const [
                OlSlot('09.00', unavailableLabel: 'Penuh'),
                OlSlot('10.00'),
                OlSlot('11.00', unavailableLabel: 'Penuh'),
              ],
              selected: _slot,
              onSelect: (s) => setState(() => _slot = s),
            ),
            const OlOverline('SORE'),
            OlSlotPicker(
              slots: const [
                OlSlot('14.00'),
                OlSlot('15.00'),
                OlSlot('16.00'),
                OlSlot('17.00', unavailableLabel: 'Penuh'),
                OlSlot('18.00'),
                OlSlot('19.00', unavailableLabel: 'Penuh'),
              ],
              selected: _slot,
              onSelect: (s) => setState(() => _slot = s),
            ),
            if (_slot != null)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const OlOverline('RINGKASAN'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: '${_dayNames[_day]}, $_day Okt · ',
                              children: [TextSpan(text: _slot, style: t.mono)],
                            ),
                            style: t.body.copyWith(fontSize: 15),
                          ),
                        ),
                        if (_usesPackage) const OlTag('Pakai paket'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Biaya', style: t.body.copyWith(color: c.muted)),
                        const Spacer(),
                        Text(
                          _usesPackage
                              ? 'Rp0 · sisa paket 1 → 0'
                              : '${Fmt.money(price)} · bayar di klinik',
                          style: t.mono.copyWith(fontSize: 14.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Text(
              'Booking akan dikonfirmasi front desk. Anda menerima notifikasi setelah diterima.',
              style: t.body.copyWith(fontSize: 14, color: c.muted),
            ),
          ],
        },
      ),
    );
  }
}
