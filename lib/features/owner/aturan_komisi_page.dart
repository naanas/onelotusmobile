import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Type { percent, nominal }

class _Component {
  _Component(this.name, this.type, this.value);
  final String name;
  _Type type;
  int value;

  String get display => type == _Type.percent ? '$value%' : Fmt.money(value);
}

/// OW-11 Aturan komisi: komponen (persen/nominal), tanggal berlaku, pratinjau.
/// Nilai awal di layar ini hanya contoh mockup — aturan komisi nyata belum
/// diputuskan mitra (spec §16), jadi owner yang mengisinya.
class AturanKomisiPage extends StatefulWidget {
  const AturanKomisiPage({super.key});

  @override
  State<AturanKomisiPage> createState() => _AturanKomisiPageState();
}

class _AturanKomisiPageState extends State<AturanKomisiPage> {
  final _rows = [
    _Component('Adjustment Therapy', _Type.percent, 25),
    _Component('Masase cedera', _Type.percent, 30),
    _Component('Titik tambahan', _Type.nominal, 15000),
    _Component('Home visit', _Type.nominal, 30000),
    _Component('Sesi dari paket', _Type.percent, 30),
  ];
  DateTime _from = DateTime(2026, 11, 1);

  int _part(_Component c, int base) =>
      c.type == _Type.percent ? base * c.value ~/ 100 : c.value;

  Future<void> _edit(_Component comp) async {
    var type = comp.type;
    var value = comp.value;
    final ok = await context.feedback.formSheet<bool>(
      title: comp.name,
      builder: (ctx, close) => StatefulBuilder(
        builder: (ctx, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OlSegmented<_Type>(
              segments: const {
                _Type.percent: 'Persen',
                _Type.nominal: 'Nominal',
              },
              value: type,
              onChanged: (v) => set(() => type = v),
            ),
            const SizedBox(height: OlSpace.md),
            if (type == _Type.nominal)
              OlMoneyField(
                label: 'Nilai',
                large: false,
                value: value,
                onChanged: (v) => value = v,
              )
            else
              OlTextField(
                label: 'Nilai',
                initialValue: '$value',
                suffixText: '%',
                mono: true,
                keyboardType: TextInputType.number,
                onChanged: (v) => value = int.tryParse(v) ?? 0,
              ),
            const SizedBox(height: OlSpace.lg),
            OlButton(label: 'Pakai nilai ini', onPressed: () => close(true)),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        comp
          ..type = type
          ..value = value;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime(2026, 10, 6);
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: now,
      lastDate: DateTime(2027, 12, 31),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _save() async {
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: 'Simpan aturan komisi?',
        message:
            'Berlaku mulai ${Fmt.dateNoDay(_from)}. Komisi yang sudah disetujui tidak berubah. Terapis diberi tahu.',
        confirmLabel: 'Simpan',
        danger: false,
      ),
    );
    if (ok && mounted) context.feedback.success('Aturan komisi disimpan.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    // Pratinjau: Adjustment + masase 1 titik + home visit (contoh mockup).
    final a = _part(_rows[0], 250000);
    final m = _part(_rows[1], 150000);
    final hv = _part(_rows[3], 300000);
    final total = a + m + hv;
    String how(_Component comp, int base) => comp.type == _Type.percent
        ? '${comp.value}% × ${Fmt.money(base)}'
        : comp.name;

    return OlDetailScaffold(
      title: 'Aturan komisi',
      foot: [OlButton(label: 'Simpan aturan', onPressed: _save)],
      children: [
        OlCard(
          padding: const EdgeInsets.fromLTRB(OlSpace.lg, 4, OlSpace.lg, 4),
          child: Column(
            children: [
              _row(context, const ['KOMPONEN', 'TIPE', 'NILAI'], head: true),
              for (final r in _rows)
                Semantics(
                  container: true,
                  button: true,
                  label:
                      '${r.name}, ${r.type == _Type.percent ? 'persen' : 'nominal'} ${r.display}. Ketuk untuk ubah.',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => _edit(r),
                    child: _row(context, [
                      r.name,
                      r.type == _Type.percent ? 'Persen' : 'Nominal',
                      r.display,
                    ]),
                  ),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                text: 'Berlaku mulai',
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: c.crit),
                  ),
                ],
              ),
              style: t.fieldLabel,
            ),
            const SizedBox(height: 8),
            Semantics(
              container: true,
              button: true,
              label: 'Berlaku mulai ${Fmt.dateNoDay(_from)}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(OlRadius.input),
                onTap: _pickDate,
                child: Container(
                  constraints: const BoxConstraints(minHeight: OlSize.input),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(OlRadius.input),
                    border: Border.all(color: c.line, width: 1.5),
                  ),
                  child: Text(
                    Fmt.dateNoDay(_from),
                    style: t.body.copyWith(fontSize: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tidak mengubah komisi yang sudah disetujui.',
              style: t.body.copyWith(fontSize: 14, color: c.muted),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pratinjau hitungan',
                style: t.heading.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Sesi Andi Pratama · Adjustment + masase 1 titik + home visit',
                style: t.body.copyWith(fontSize: 14, color: c.muted),
              ),
              const SizedBox(height: 6),
              OlMoneyRow(label: how(_rows[0], 250000), amount: a),
              OlMoneyRow(label: how(_rows[1], 150000), amount: m),
              OlMoneyRow(label: how(_rows[3], 300000), amount: hv),
              OlMoneyTotal(label: 'Komisi terapis', amount: total),
            ],
          ),
        ),
        Center(
          child: OlButton.text(
            label: '+ Pengecualian per terapis',
            onPressed: () => context.feedback.info(
              'Pengecualian per terapis menunggu keputusan workshop mitra.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, List<String> cells, {bool head = false}) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              cells[0],
              style: head ? t.overline : t.body.copyWith(fontSize: 15),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              cells[1],
              style: head ? t.overline : t.body.copyWith(fontSize: 15),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              cells[2],
              textAlign: TextAlign.right,
              style: head
                  ? t.overline
                  : t.mono.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
