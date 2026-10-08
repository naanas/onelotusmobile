import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

/// TR-09 Home visit: rute, alamat & patokan, peringatan medis, checklist alat,
/// check-in dalam radius, tagih & batalkan di lokasi.
class HomeVisitPage extends StatefulWidget {
  const HomeVisitPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<HomeVisitPage> createState() => _HomeVisitPageState();
}

class _HomeVisitPageState extends State<HomeVisitPage> {
  final _tools = {
    'Lampu infrared': true,
    'Minyak & handuk': true,
    'Matras lipat': false,
  };
  String? _checkIn;
  String? _checkOut;

  Future<void> _checkInNow() async {
    // Slicing UI: lokasi contoh dianggap di luar radius untuk menampilkan alur §12.4.
    final r = await context.feedback.choose(
      const ConfirmSpec(
        title: 'Kamu ±600 m dari alamat. Tetap check-in?',
        message:
            'Check-in aktif dalam radius 200 m. Tulis alasannya agar owner bisa meninjau.',
        confirmLabel: 'Tetap check-in',
        danger: false,
        reasonLabel: 'Alasan',
      ),
    );
    if (!r.confirmed || !mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _checkIn = '12.58');
    context.feedback.success('Check-in tercatat 12.58.');
  }

  Future<void> _cancel() async {
    final r = await context.feedback.choose(
      const ConfirmSpec(
        title: 'Batalkan home visit di lokasi?',
        message:
            'Check-in tetap tercatat untuk ongkos transport. Kasir & pasien akan diberi tahu.',
        confirmLabel: 'Batalkan di lokasi',
        reasonLabel: 'Alasan',
      ),
    );
    if (r.confirmed && mounted) {
      context.feedback.success(
        'Home visit dibatalkan. Kasir sudah diberi tahu.',
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final done = _tools.values.where((v) => v).length;

    return OlDetailScaffold(
      title: 'Budi Hartono',
      actions: const [OlTag('Home visit · 13.00', tone: OlTagTone.warn)],
      below: Text(
        'Relaksasi Premium ±90 mnt',
        style: t.body.copyWith(fontSize: 15, color: c.muted),
      ),
      foot: [
        OlButton(
          label: _checkIn == null
              ? 'Check-in di lokasi'
              : (_checkOut == null ? 'Check-out' : 'Sudah check-out'),
          icon: OlIcons.pin,
          onPressed: _checkIn == null
              ? _checkInNow
              : _checkOut == null
              ? () => setState(() => _checkOut = '14.36')
              : null,
        ),
        OlFootRow(
          children: [
            OlButton.secondary(
              label: 'Tagih',
              onPressed: () =>
                  context.push(Routes.terapisTagih(widget.sessionId)),
            ),
            OlButton(
              label: 'Batalkan di lokasi',
              variant: OlButtonVariant.dangerSecondary,
              onPressed: _cancel,
            ),
          ],
        ),
      ],
      children: [
        const RouteMapPreview(),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jl. Raya Sukun No. 12, Malang',
                          style: t.bodyStrong.copyWith(fontSize: 15),
                        ),
                        Text(
                          'Patokan: pagar hijau, sebelah warung',
                          style: t.body.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '4,2 km',
                        style: t.mono.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('±14 mnt', style: t.body.copyWith(color: c.muted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OlFootRow(
                children: [
                  OlButton.secondary(
                    label: 'Buka Maps',
                    small: true,
                    onPressed: () =>
                        context.feedback.info('Membuka Google Maps…'),
                  ),
                  OlButton.secondary(
                    label: 'Hubungi via klinik',
                    small: true,
                    onPressed: () => context.feedback.success(
                      'Permintaan menghubungi pasien dikirim ke front desk.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const OlBanner(
          tone: OlBannerTone.crit,
          message: 'LBP kronis — hindari tekanan kuat L4–L5.',
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Checklist alat',
                      style: t.heading.copyWith(fontSize: 17),
                    ),
                  ),
                  Text(
                    '$done/${_tools.length}',
                    style: t.body.copyWith(color: c.muted),
                  ),
                ],
              ),
              for (final e in _tools.entries)
                OlCheckbox(
                  label: e.key,
                  value: e.value,
                  strikeWhenChecked: true,
                  onChanged: (v) => setState(() => _tools[e.key] = v),
                ),
            ],
          ),
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Check-in',
                      style: t.body.copyWith(fontSize: 15, color: c.muted),
                    ),
                  ),
                  Text(
                    'Check-out',
                    style: t.body.copyWith(fontSize: 15, color: c.muted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _checkIn ?? '–',
                      style: t.mono.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _checkOut ?? '–',
                    style: t.mono.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Check-in aktif dalam radius 200 m dari alamat.',
                style: t.body.copyWith(color: c.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
