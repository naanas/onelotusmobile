import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'owner_widgets.dart';

class _Service {
  _Service(
    this.name,
    this.price,
    this.minutes, {
    this.perPoint,
    this.injury,
    this.memberPct,
    this.homeVisit = false,
    this.active = true,
  });

  final String name;
  int price;
  int minutes;
  int? perPoint;
  int? injury;
  int? memberPct;
  bool homeVisit;
  bool active;

  String get detail => !active
      ? 'Nonaktif'
      : [
          '$minutes mnt',
          if (memberPct != null)
            'member ${Fmt.money(price * (100 - memberPct!) ~/ 100)}',
          if (perPoint != null) '+${Fmt.money(perPoint!)}/titik',
          if (homeVisit && memberPct == null) 'bisa home visit',
        ].join(' · ');
}

/// OW-09 Layanan & harga per cabang. Perubahan harga hanya untuk tagihan baru;
/// riwayat harga disimpan.
class LayananPage extends StatefulWidget {
  const LayananPage({super.key});

  @override
  State<LayananPage> createState() => _LayananPageState();
}

class _LayananPageState extends State<LayananPage> {
  String _branch = 'pusat';
  final _services = {
    'pusat': [
      _Service('Adjustment Therapy', 250000, 60, memberPct: 10),
      _Service(
        'Masase cedera ringan',
        150000,
        45,
        perPoint: 50000,
        injury: 100000,
        memberPct: 10,
      ),
      _Service('Relaksasi Premium', 300000, 90, homeVisit: true),
      _Service('Bekam', 120000, 45, active: false),
    ],
    'batu': [
      _Service('Adjustment Therapy', 230000, 60, memberPct: 10),
      _Service('Masase cedera ringan', 140000, 45, perPoint: 45000),
    ],
  };
  late _Service _editing = _services['pusat']![1];
  final _scrollKey = GlobalKey();

  // Draf form (disalin dari item saat dipilih).
  late int _price;
  late int _minutes;
  late int _perPoint;
  late int _injury;
  late int _member;
  late bool _home;
  late bool _active;
  final _minutesCtl = TextEditingController();
  final _memberCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(_editing);
  }

  void _load(_Service s) {
    _editing = s;
    _price = s.price;
    _minutes = s.minutes;
    _perPoint = s.perPoint ?? 0;
    _injury = s.injury ?? 0;
    _member = s.memberPct ?? 0;
    _home = s.homeVisit;
    _active = s.active;
    _minutesCtl.text = '$_minutes';
    _memberCtl.text = '$_member%';
  }

  @override
  void dispose() {
    _minutesCtl.dispose();
    _memberCtl.dispose();
    super.dispose();
  }

  void _select(_Service s) {
    setState(() => _load(s));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _scrollKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: OlMotion.of(context, OlMotion.slow),
          curve: OlMotion.curve,
        );
      }
    });
  }

  Future<void> _add() async {
    final name = await context.feedback.formSheet<String>(
      title: 'Layanan baru',
      builder: (ctx, close) {
        final ctl = TextEditingController();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OlTextField(
              label: 'Nama layanan',
              isRequired: true,
              controller: ctl,
              hint: 'Mis. Terapi Infrared',
            ),
            const SizedBox(height: OlSpace.lg),
            OlButton(
              label: 'Lanjut atur harga',
              onPressed: () {
                if (ctl.text.trim().isNotEmpty) close(ctl.text.trim());
              },
            ),
          ],
        );
      },
    );
    if (name == null || !mounted) return;
    final s = _Service(name, 0, 60);
    setState(() => _services[_branch]!.add(s));
    _select(s);
  }

  void _save() {
    setState(() {
      _editing
        ..price = _price
        ..minutes = int.tryParse(_minutesCtl.text) ?? _minutes
        ..perPoint = _perPoint == 0 ? null : _perPoint
        ..injury = _injury == 0 ? null : _injury
        ..memberPct = _member == 0 ? null : _member
        ..homeVisit = _home
        ..active = _active;
    });
    context.feedback.success('Harga ${_editing.name} disimpan.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final list = _services[_branch]!;
    return OlDetailScaffold(
      title: 'Layanan & harga',
      actions: [
        OlButton(
          label: '+ Layanan',
          small: true,
          expand: false,
          onPressed: _add,
        ),
      ],
      foot: [OlButton(label: 'Simpan perubahan', onPressed: _save)],
      children: [
        OlSegmented<String>(
          segments: const {'pusat': 'Klinik Pusat', 'batu': 'Cabang Batu'},
          value: _branch,
          onChanged: (v) => setState(() {
            _branch = v;
            _load(_services[v]!.first);
          }),
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, s) in list.indexed)
                Opacity(
                  opacity: s.active ? 1 : 0.5,
                  child: OlListItem(
                    title: s.name,
                    subtitle: s.detail,
                    trailing: Text(
                      Fmt.money(s.price),
                      style: t.mono.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    divider: i < list.length - 1,
                    onTap: () => _select(s),
                  ),
                ),
            ],
          ),
        ),
        OlOverline('EDIT · ${_editing.name.toUpperCase()}', key: _scrollKey),
        OlCard(
          key: ValueKey(_editing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: OlMoneyField(
                      label: 'Harga dasar',
                      isRequired: true,
                      large: false,
                      value: _price,
                      onChanged: (v) => setState(() => _price = v),
                    ),
                  ),
                  const SizedBox(width: OlSpace.md),
                  Expanded(
                    child: OlTextField(
                      label: 'Durasi',
                      isRequired: true,
                      controller: _minutesCtl,
                      mono: true,
                      suffixText: 'mnt',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: OlMoneyField(
                      label: 'Per titik tambahan',
                      large: false,
                      value: _perPoint,
                      onChanged: (v) => setState(() => _perPoint = v),
                    ),
                  ),
                  const SizedBox(width: OlSpace.md),
                  Expanded(
                    child: OlMoneyField(
                      label: 'Tambahan cedera',
                      large: false,
                      value: _injury,
                      onChanged: (v) => setState(() => _injury = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              OlTextField(
                label: 'Harga member',
                controller: _memberCtl,
                mono: true,
                suffixText: 'potongan',
                keyboardType: TextInputType.number,
                onChanged: (v) => _member =
                    int.tryParse(v.replaceAll(RegExp(r'\D'), '')) ?? 0,
              ),
              const SizedBox(height: OlSpace.sm),
              OwToggleRow(
                label: 'Tersedia untuk home visit',
                value: _home,
                onChanged: (v) => setState(() => _home = v),
              ),
              OwToggleRow(
                label: 'Aktif',
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: OlSpace.sm),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.brandSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Perubahan harga berlaku untuk tagihan baru. Riwayat harga disimpan.',
                  style: t.body.copyWith(fontSize: 14.5, color: c.brandDeep),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
