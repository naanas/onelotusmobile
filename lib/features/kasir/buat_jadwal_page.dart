import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-06 Buat / ubah jadwal: pasien → layanan → lokasi & terapis → waktu → ringkasan.
/// Bentrok dicegah di SlotPicker, bukan setelah simpan (§5.11).
class BuatJadwalPage extends StatefulWidget {
  const BuatJadwalPage({super.key});

  @override
  State<BuatJadwalPage> createState() => _BuatJadwalPageState();
}

class _BuatJadwalPageState extends State<BuatJadwalPage> {
  static const _titles = [
    'Pilih pasien',
    'Pilih layanan',
    'Lokasi & terapis',
    'Pilih waktu',
    'Ringkasan',
  ];
  int _step = 0;
  String _patient = 'Andi Pratama · #0412';
  String _service = 'Adjustment Therapy · 60 mnt';
  String _location = 'Klinik Pusat · ruang 2';
  String _therapist = 'Dimas';
  int _dayIndex = 2;
  String? _slot = '11.00';
  bool _busy = false;

  static const _days = [
    ('Sel', 6),
    ('Rab', 7),
    ('Kam', 8),
    ('Jum', 9),
    ('Sab', 10),
    ('Min', 11),
    ('Sen', 12),
  ];

  bool get _canNext => switch (_step) {
    3 => _slot != null,
    _ => true,
  };

  Future<void> _next() async {
    if (_step < 4) {
      setState(() => _step++);
      return;
    }
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    context.feedback.success(
      'Jadwal tersimpan. Pengingat WhatsApp dikirim H-1.',
    );
    Navigator.of(context).maybePop();
  }

  Widget _options(
    List<String> options,
    String value,
    ValueChanged<String> onPick,
  ) => OlRadioList<String>(
    options: [for (final o in options) OlRadioOption(value: o, title: o)],
    value: value,
    onChanged: (v) => setState(() => onPick(v)),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    final summary = OlCard(
      child: Column(
        children: [
          OlInfoRow(label: 'Pasien', value: _patient),
          if (_step >= 1) OlInfoRow(label: 'Layanan', value: _service),
          if (_step >= 2) OlInfoRow(label: 'Lokasi', value: _location),
          if (_step >= 2) OlInfoRow(label: 'Terapis', value: _therapist),
          if (_step >= 4)
            OlInfoRow(
              label: 'Waktu',
              value:
                  '${_days[_dayIndex].$1}, ${_days[_dayIndex].$2} Okt · $_slot',
            ),
        ],
      ),
    );

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: OlDetailScaffold(
        title: 'Buat jadwal',
        close: true,
        context_: 'Langkah ${_step + 1} dari 5 · ${_titles[_step]}',
        below: OlStepProgress(count: 5, current: _step),
        foot: [
          OlButton(
            label: switch (_step) {
              3 => 'Lanjut ke ringkasan',
              4 => 'Simpan jadwal',
              _ => 'Lanjut',
            },
            loading: _busy,
            onPressed: _canNext ? _next : null,
          ),
        ],
        children: [
          if (_step > 0) summary,
          ...switch (_step) {
            0 => [
              OlSearchField(
                hint: 'Cari nama, #nomor, atau 4 digit HP',
                onChanged: (_) {},
              ),
              _options(
                const [
                  'Andi Pratama · #0412',
                  'Rina Setiawati · #0387',
                  'Dewi Lestari · #0402',
                ],
                _patient,
                (v) => _patient = v,
              ),
            ],
            1 => [
              _options(
                const [
                  'Adjustment Therapy · 60 mnt',
                  'Masase Cedera Ringan · 60 mnt',
                  'Masase Cedera · 75 mnt',
                  'Relaksasi Premium · 90 mnt',
                ],
                _service,
                (v) => _service = v,
              ),
            ],
            2 => [
              const OlOverline('Lokasi'),
              _options(
                const [
                  'Klinik Pusat · ruang 2',
                  'Klinik Pusat · ruang 1',
                  'Home visit',
                ],
                _location,
                (v) => _location = v,
              ),
              const OlOverline('Terapis'),
              _options(
                const ['Dimas', 'Laras', 'Fajar', 'Siapa saja'],
                _therapist,
                (v) => _therapist = v,
              ),
            ],
            3 => [
              Row(
                children: [
                  for (final (i, (d, n)) in _days.indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Semantics(
                        container: true,
                        button: d != 'Min',
                        selected: i == _dayIndex,
                        label: d == 'Min' ? '$d $n, tutup' : '$d $n',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: d == 'Min'
                              ? null
                              : () => setState(() {
                                  _dayIndex = i;
                                  _slot = null;
                                }),
                          child: AnimatedContainer(
                            duration: OlMotion.of(context, OlMotion.fast),
                            height: 64,
                            decoration: BoxDecoration(
                              color: i == _dayIndex
                                  ? c.brandDeep
                                  : (d == 'Min' ? c.surfaceAlt : c.surface),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: d == 'Min' ? null : OlShadow.sh1,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  d,
                                  style: t.caption.copyWith(
                                    color: i == _dayIndex
                                        ? const Color(0xFFA9D8F2)
                                        : (d == 'Min' ? c.faint : c.muted),
                                  ),
                                ),
                                Text(
                                  '$n',
                                  style: t.heading.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: i == _dayIndex
                                        ? Colors.white
                                        : (d == 'Min' ? c.faint : c.fg),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const OlOverline('Pagi'),
              OlSlotPicker(
                slots: const [
                  OlSlot('08.00', unavailableLabel: 'Penuh'),
                  OlSlot('09.00'),
                  OlSlot('10.00', unavailableLabel: 'Penuh'),
                  OlSlot('11.00'),
                ],
                selected: _slot,
                onSelect: (v) => setState(() => _slot = v),
              ),
              const OlOverline('Siang & sore'),
              OlSlotPicker(
                slots: const [
                  OlSlot('12.00', unavailableLabel: 'Istirahat'),
                  OlSlot('13.00'),
                  OlSlot('14.00', unavailableLabel: 'Penuh'),
                  OlSlot('15.00'),
                  OlSlot('16.00'),
                  OlSlot('17.00', unavailableLabel: 'Penuh'),
                ],
                selected: _slot,
                onSelect: (v) => setState(() => _slot = v),
              ),
              Text(
                'Slot dihitung dari jam buka, durasi layanan, serta ketersediaan terapis & ruang — jadwal bentrok tidak bisa dipilih.',
                style: t.body.copyWith(color: c.muted),
              ),
            ],
            _ => [
              const OlBanner(
                tone: OlBannerTone.ok,
                icon: OlIcons.checkCircle,
                message:
                    'Slot masih tersedia. Pasien & terapis diberi tahu setelah disimpan.',
              ),
            ],
          },
        ],
      ),
    );
  }
}
