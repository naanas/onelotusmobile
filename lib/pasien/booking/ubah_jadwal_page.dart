import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

const _days = [
  OlDay('Rab', 7),
  OlDay('Kam', 8),
  OlDay('Jum', 9),
  OlDay('Sab', 10),
  OlDay('Min', 11, closed: true),
  OlDay('Sen', 12),
  OlDay('Sel', 13),
];

const _dayNames = {
  7: 'Rabu',
  8: 'Kamis',
  9: 'Jumat',
  10: 'Sabtu',
  12: 'Senin',
  13: 'Selasa',
};

/// PS-11 Ubah / batalkan jadwal sampai batas waktu (contoh mockup: H-1 pukul 18.00 —
/// batas sebenarnya menunggu keputusan klinik). Setelah lewat: "Hubungi klinik".
class UbahJadwalPage extends StatefulWidget {
  const UbahJadwalPage({super.key, this.pastDeadline = false});

  final bool pastDeadline;

  @override
  State<UbahJadwalPage> createState() => _UbahJadwalPageState();
}

class _UbahJadwalPageState extends State<UbahJadwalPage> {
  int _day = 9;
  String? _slot = '15.00';

  Future<void> _cancel() async {
    final r = await context.feedback.choose(
      const ConfirmSpec(
        title: 'Batalkan booking Kamis, 8 Okt?',
        message:
            'Kuota paket dikembalikan karena dibatalkan sebelum batas waktu.',
        confirmLabel: 'Batalkan booking',
        cancelLabel: 'Kembali',
      ),
    );
    if (r.choice == ConfirmChoice.confirm && mounted) {
      context.feedback.success('Booking dibatalkan. Kuota paket dikembalikan.');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    if (widget.pastDeadline) {
      return OlDetailScaffold(
        title: 'Ubah jadwal',
        context_: 'Kamis, 8 Okt · 16.00 · Dimas',
        foot: [
          OlButton(
            label: 'Hubungi klinik',
            icon: OlIcons.chat,
            onPressed: () => context.feedback.info('Membuka WhatsApp klinik…'),
          ),
        ],
        children: const [
          OlBanner(
            tone: OlBannerTone.warn,
            icon: OlIcons.clock,
            message:
                'Batas ubah/batal sudah lewat (Rabu, 7 Okt pukul 18.00). Hubungi klinik untuk perubahan.',
          ),
        ],
      );
    }

    return OlDetailScaffold(
      title: 'Ubah jadwal',
      context_: 'Kamis, 8 Okt · 16.00 · Dimas',
      foot: [
        OlButton(
          label: 'Ajukan perubahan',
          onPressed: _slot == null
              ? null
              : () {
                  context.feedback.success(
                    'Perubahan diajukan. Menunggu konfirmasi front desk.',
                  );
                  Navigator.of(context).maybePop();
                },
        ),
      ],
      children: [
        OlBanner(
          icon: OlIcons.clock,
          message:
              'Anda bisa mengubah atau membatalkan sampai Rabu, 7 Okt pukul 18.00.',
        ),
        OlDayStrip(
          days: _days,
          selected: _day,
          onSelect: (d) => setState(() {
            _day = d;
            _slot = null;
          }),
        ),
        OlSlotPicker(
          slots: const [
            OlSlot('10.00'),
            OlSlot('11.00', unavailableLabel: 'Penuh'),
            OlSlot('14.00'),
            OlSlot('15.00'),
            OlSlot('16.00', unavailableLabel: 'Penuh'),
            OlSlot('17.00'),
          ],
          selected: _slot,
          onSelect: (s) => setState(() => _slot = s),
        ),
        if (_slot != null)
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Jadwal baru', style: t.body.copyWith(color: c.muted)),
                    const Spacer(),
                    Text.rich(
                      TextSpan(
                        text: '${_dayNames[_day]}, $_day Okt · ',
                        children: [
                          TextSpan(
                            text: _slot,
                            style: t.mono.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      style: t.bodyStrong,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Paket tetap dipakai · tidak ada biaya tambahan',
                  style: t.body.copyWith(fontSize: 14, color: c.muted),
                ),
              ],
            ),
          ),
        Divider(color: c.line, height: 1),
        Center(
          child: OlButton(
            label: 'Batalkan booking ini',
            variant: OlButtonVariant.dangerText,
            expand: false,
            onPressed: _cancel,
          ),
        ),
        Text(
          'Kuota paket dikembalikan bila dibatalkan sebelum batas waktu.',
          textAlign: TextAlign.center,
          style: t.body.copyWith(fontSize: 14, color: c.muted),
        ),
      ],
    );
  }
}
