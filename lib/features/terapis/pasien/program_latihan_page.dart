import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

class _Exercise {
  _Exercise(this.name, this.dose, this.freq, this.area);
  final String name;
  String dose;
  String freq;
  final String area;
}

/// TR-13 Kirim program latihan (Fase 3): pustaka per area tubuh, atur set/repetisi, kirim ke app pasien.
class ProgramLatihanPage extends StatefulWidget {
  const ProgramLatihanPage({super.key, required this.patientId});

  final String patientId;

  @override
  State<ProgramLatihanPage> createState() => _ProgramLatihanPageState();
}

class _ProgramLatihanPageState extends State<ProgramLatihanPage> {
  String _area = 'Ankle & kaki';
  final _selected = [
    _Exercise('Ankle alphabet', '2 set', '1×/hari', 'Ankle & kaki'),
    _Exercise('Calf raise', '3×12', '2×/hari', 'Ankle & kaki'),
    _Exercise('Single-leg stand', '3×30 dtk', '1×/hari', 'Ankle & kaki'),
  ];
  final _note = TextEditingController(text: 'Berhenti bila nyeri di atas 4.');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _edit(_Exercise e) async {
    final dose = TextEditingController(text: e.dose);
    final freq = TextEditingController(text: e.freq);
    final ok = await context.feedback.formSheet<bool>(
      title: e.name,
      builder: (context, close) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OlTextField(label: 'Set × repetisi', controller: dose, mono: true),
          const SizedBox(height: OlSpace.lg),
          OlTextField(label: 'Frekuensi', controller: freq),
          const SizedBox(height: OlSpace.xl),
          OlButton(label: 'Simpan', onPressed: () => close(true)),
          OlButton(
            label: 'Hapus dari program',
            variant: OlButtonVariant.dangerText,
            onPressed: () => close(false),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      if (ok == true) {
        e
          ..dose = dose.text
          ..freq = freq.text;
      } else if (ok == false) {
        _selected.remove(e);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget pill(String s, {bool mono = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(OlRadius.pill),
      ),
      child: Text(
        s,
        style: (mono ? t.mono : t.body).copyWith(fontSize: 13, color: c.muted),
      ),
    );

    return OlDetailScaffold(
      title: 'Program latihan',
      context_: 'Untuk Rina Setiawati · ankle kiri',
      close: true,
      foot: [
        OlFootRow(
          children: [
            OlButton.secondary(
              label: 'Pratinjau',
              onPressed: () => context.feedback.info(
                'Pratinjau tampilan di aplikasi pasien.',
              ),
            ),
            OlButton(
              label: 'Kirim ke pasien',
              onPressed: _selected.isEmpty
                  ? null
                  : () {
                      context.feedback.success(
                        'Program latihan terkirim ke Rina.',
                      );
                      Navigator.of(context).maybePop();
                    },
            ),
          ],
        ),
      ],
      children: [
        OlSearchField(hint: 'Cari di pustaka latihan', onChanged: (_) {}),
        Wrap(
          spacing: OlSpace.sm,
          children: [
            for (final a in const ['Ankle & kaki', 'Lutut', 'Punggung', 'Bahu'])
              OlChip(
                label: a,
                selected: _area == a,
                onTap: () => setState(() => _area = a),
              ),
          ],
        ),
        OlOverline('Dipilih · ${_selected.length}'),
        if (_selected.isNotEmpty)
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, e) in _selected.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: i < _selected.length - 1
                          ? Border(bottom: BorderSide(color: c.line))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16344B),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Semantics(
                            label: 'Putar video ${e.name}',
                            button: true,
                            child: const OlPlayGlyph(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.name,
                                style: t.bodyStrong.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: [
                                  pill(e.dose, mono: true),
                                  pill(e.freq),
                                ],
                              ),
                            ],
                          ),
                        ),
                        OlIconButton(
                          icon: OlIcons.edit,
                          semanticLabel: 'Ubah ${e.name}',
                          onPressed: () => _edit(e),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OlTextField(label: 'Mulai', initialValue: '7 Okt'),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: OlTextField(label: 'Selesai', initialValue: '20 Okt'),
            ),
          ],
        ),
        OlTextField(
          label: 'Catatan untuk pasien',
          controller: _note,
          maxLines: 3,
        ),
      ],
    );
  }
}
