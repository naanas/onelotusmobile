import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// OW-17 Cabang & ruang: alamat + titik peta, radius check-in home visit,
/// transport per km, jam operasional, daftar ruang.
class CabangPage extends StatefulWidget {
  const CabangPage({super.key});

  @override
  State<CabangPage> createState() => _CabangPageState();
}

class _CabangPageState extends State<CabangPage> {
  String _branch = 'Klinik Pusat Malang';
  int _radius = 200;
  int _transport = 6000;
  final _rooms = ['Ruang 1', 'Ruang 2', 'Ruang 3 · adjustment'];
  final _hours = [
    ('Senin–Jumat', '08.00–20.00'),
    ('Sabtu', '08.00–17.00'),
    ('Minggu', null),
  ];

  Future<void> _switchBranch() async {
    final b = await context.feedback.sheet<String>(
      title: 'Pilih cabang',
      actions: [
        for (final b in const ['Klinik Pusat Malang', 'Cabang Batu'])
          SheetAction(
            b,
            b,
            variant: b == _branch
                ? OlButtonVariant.primary
                : OlButtonVariant.secondary,
          ),
      ],
    );
    if (b != null) setState(() => _branch = b);
  }

  Future<void> _addRoom() async {
    final name = await context.feedback.formSheet<String>(
      title: 'Ruang baru',
      builder: (ctx, close) {
        var v = 'Ruang ${_rooms.length + 1}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OlTextField(
              label: 'Nama ruang',
              initialValue: v,
              onChanged: (s) => v = s,
            ),
            const SizedBox(height: OlSpace.lg),
            OlButton(
              label: 'Tambah ruang',
              onPressed: () {
                if (v.trim().isNotEmpty) close(v.trim());
              },
            ),
          ],
        );
      },
    );
    if (name != null) setState(() => _rooms.add(name));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: _branch,
      titleTrailing: OlButton.text(label: 'Ganti', onPressed: _switchBranch),
      foot: [
        OlButton(
          label: 'Simpan cabang',
          onPressed: () => context.feedback.success('$_branch disimpan.'),
        ),
      ],
      children: [
        OlTextField(
          key: ValueKey('addr-$_branch'),
          label: 'Alamat',
          isRequired: true,
          initialValue: _branch.startsWith('Klinik')
              ? 'Jl. Soekarno-Hatta No. 9, Lowokwaru'
              : 'Jl. Diponegoro No. 21, Batu',
        ),
        OlPinMap(
          height: 112,
          radiusMeters: _radius,
          semanticLabel:
              'Titik lokasi cabang dengan radius check-in $_radius meter',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OlTextField(
                label: 'Radius check-in',
                initialValue: '$_radius',
                mono: true,
                suffixText: 'm',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) =>
                    setState(() => _radius = int.tryParse(v) ?? _radius),
              ),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: OlMoneyField(
                label: 'Transport / km',
                large: false,
                value: _transport,
                onChanged: (v) => setState(() => _transport = v),
              ),
            ),
          ],
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Jam operasional', style: t.heading.copyWith(fontSize: 16)),
              const SizedBox(height: 6),
              for (final (day, h) in _hours)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(day, style: t.body.copyWith(fontSize: 15)),
                      ),
                      Text(
                        h ?? 'Tutup',
                        style: h == null
                            ? t.body.copyWith(color: c.muted)
                            : t.mono.copyWith(fontSize: 14.5),
                      ),
                    ],
                  ),
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
                      'Ruang',
                      style: t.heading.copyWith(fontSize: 16),
                    ),
                  ),
                  OlButton.text(label: '+ Ruang', onPressed: _addRoom),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [for (final r in _rooms) OlChip(label: r)],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
