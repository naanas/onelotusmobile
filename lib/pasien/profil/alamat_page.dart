import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

class _Address {
  const _Address(this.label, this.text, this.inRange, {this.distance});
  final String label;
  final String text;
  final bool inRange;
  final String? distance;
}

/// PS-19 Alamat home visit tersimpan + tambah alamat (titik peta wajib).
/// Jangkauan home visit dihitung dari cabang (radius dari OW-17).
class AlamatPage extends StatefulWidget {
  const AlamatPage({super.key});

  @override
  State<AlamatPage> createState() => _AlamatPageState();
}

class _AlamatPageState extends State<AlamatPage> {
  final _items = [
    const _Address(
      'Rumah',
      'Jl. Bunga Kopi No. 14, Lowokwaru · patokan: pagar biru',
      true,
      distance: '3,1 km',
    ),
    const _Address(
      'Rumah orang tua',
      'Jl. Raya Karangploso Km 5, Kab. Malang',
      false,
    ),
  ];
  String _label = 'Kantor';
  final _text = TextEditingController(text: 'Jl. Ijen No. 25, Klojen');
  bool _pinned = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    setState(() {
      _items.add(_Address(_label, _text.text.trim(), true, distance: '2,4 km'));
      _text.clear();
      _pinned = false;
    });
    context.feedback.success('Alamat disimpan.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Alamat home visit',
      foot: [
        OlButton(
          label: 'Simpan alamat',
          onPressed: _text.text.trim().isNotEmpty && _pinned ? _save : null,
        ),
      ],
      children: [
        for (final a in _items)
          OlCard(
            semanticLabel:
                '${a.label}. ${a.text}. ${a.inRange ? 'Dalam jangkauan ${a.distance}' : 'Di luar jangkauan home visit'}',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OlIcon(
                  a.label.startsWith('Rumah') && a.inRange
                      ? OlIcons.home
                      : OlIcons.branch,
                  color: a.inRange ? c.brand : c.muted,
                ),
                const SizedBox(width: OlSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.label, style: t.bodyStrong.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(a.text, style: t.body.copyWith(color: c.muted)),
                      const SizedBox(height: 8),
                      a.inRange
                          ? OlTag(
                              'Dalam jangkauan · ${a.distance}',
                              tone: OlTagTone.ok,
                            )
                          : const OlTag(
                              'Di luar jangkauan home visit',
                              tone: OlTagTone.crit,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const OlOverline('TAMBAH ALAMAT'),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Label', style: t.fieldLabel),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final l in const ['Rumah', 'Kantor', 'Lainnya'])
                    OlChip(
                      label: l,
                      selected: _label == l,
                      onTap: () => setState(() => _label = l),
                    ),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              OlTextField(
                label: 'Alamat',
                isRequired: true,
                controller: _text,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: OlSpace.md),
              Semantics(
                button: true,
                label: _pinned
                    ? 'Titik peta sudah dipasang'
                    : 'Ketuk peta untuk memasang titik',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => setState(() => _pinned = true),
                  child: OlPinMap(
                    height: 100,
                    pinColor: _pinned ? c.brand : c.crit,
                    semanticLabel: 'Peta alamat',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: _pinned
                      ? 'Titik terpasang · dalam jangkauan 2,4 km'
                      : 'Geser pin ke titik yang tepat',
                  children: [
                    if (!_pinned)
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: c.crit),
                      ),
                  ],
                ),
                style: t.body.copyWith(
                  fontSize: 14,
                  color: _pinned ? c.ok : c.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
