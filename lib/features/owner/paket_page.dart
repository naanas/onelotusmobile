import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'owner_widgets.dart';

class _Package {
  _Package(
    this.name,
    this.detail,
    this.price,
    this.meta, {
    this.services = const [],
    this.sessions,
    this.days = 60,
  });

  final String name;
  final String detail;
  int price;
  final String meta;
  List<String> services;
  int? sessions;
  int days;
}

const _allServices = [
  'Masase cedera ringan',
  'Adjustment Therapy',
  'Relaksasi Premium',
  'Infrared',
];

/// OW-10 Paket & membership. Perubahan tidak memengaruhi paket yang sudah terjual.
/// Aturan kuota/kedaluwarsa paket menunggu workshop mitra (spec §16) — hanya isian.
class PaketPage extends StatefulWidget {
  const PaketPage({super.key});

  @override
  State<PaketPage> createState() => _PaketPageState();
}

class _PaketPageState extends State<PaketPage> {
  final _items = [
    _Package(
      'Cedera Ringan 5×',
      'Masase cedera ringan · 5 sesi · 60 hari',
      625000,
      'terjual 23 · bulan ini',
      services: ['Masase cedera ringan'],
      sessions: 5,
    ),
    _Package(
      'Cedera Ringan 10×',
      '10 sesi · 120 hari',
      1150000,
      'terjual 7',
      services: ['Masase cedera ringan'],
      sessions: 10,
      days: 120,
    ),
    _Package(
      'Member Tahunan',
      'Potongan 10% semua layanan · 365 hari',
      300000,
      '68 member',
      days: 365,
    ),
  ];
  late _Package _editing = _items.first;
  final _sessions = TextEditingController();
  final _days = TextEditingController();
  int _price = 0;

  @override
  void initState() {
    super.initState();
    _load(_editing);
  }

  void _load(_Package p) {
    _editing = p;
    _sessions.text = p.sessions?.toString() ?? '';
    _days.text = '${p.days}';
    _price = p.price;
  }

  @override
  void dispose() {
    _sessions.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _addService() async {
    final pick = await context.feedback.sheet<String>(
      title: 'Tambah layanan',
      actions: [
        for (final s in _allServices)
          if (!_editing.services.contains(s))
            SheetAction(s, s, variant: OlButtonVariant.secondary),
      ],
    );
    if (pick != null) {
      setState(() => _editing.services = [..._editing.services, pick]);
    }
  }

  void _save() {
    setState(() {
      _editing
        ..sessions = int.tryParse(_sessions.text)
        ..days = int.tryParse(_days.text) ?? _editing.days
        ..price = _price;
    });
    context.feedback.success('${_editing.name} disimpan.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final isMember = _editing.sessions == null;
    return OlDetailScaffold(
      title: 'Paket & membership',
      actions: [
        OlButton(
          label: '+ Paket',
          small: true,
          expand: false,
          onPressed: () => context.feedback.info(
            'Isi nama paket, layanan, sesi, dan harga di form di bawah.',
          ),
        ),
      ],
      foot: [OlButton(label: 'Simpan paket', onPressed: _save)],
      children: [
        for (final p in _items)
          OwCatalogCard(
            title: p.name,
            detail: p.detail,
            price: Fmt.money(p.price),
            meta: p.meta,
            selected: identical(p, _editing),
            onTap: () => setState(() => _load(p)),
          ),
        OlOverline('EDIT · ${_editing.name.toUpperCase()}'),
        OlCard(
          key: ValueKey(_editing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isMember) ...[
                Text.rich(
                  TextSpan(
                    text: 'Layanan dicakup',
                    children: [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: c.crit),
                      ),
                    ],
                  ),
                  style: t.fieldLabel,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in _editing.services)
                      OlChip(
                        label: s,
                        selected: true,
                        onRemove: _editing.services.length > 1
                            ? () => setState(
                                () => _editing.services = [
                                  for (final x in _editing.services)
                                    if (x != s) x,
                                ],
                              )
                            : null,
                      ),
                    OlChip(label: '+ Tambah', onTap: _addService),
                  ],
                ),
                const SizedBox(height: OlSpace.md),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMember) ...[
                    Expanded(
                      child: OlTextField(
                        label: 'Sesi',
                        controller: _sessions,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: OlSpace.md),
                  ],
                  Expanded(
                    child: OlTextField(
                      label: 'Hari',
                      controller: _days,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              OlMoneyField(
                label: 'Harga',
                large: false,
                value: _price,
                onChanged: (v) => setState(() => _price = v),
              ),
              const SizedBox(height: OlSpace.md),
              Text(
                'Perubahan tidak memengaruhi paket yang sudah terjual.',
                style: t.body.copyWith(fontSize: 14, color: c.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
