import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

class _Move {
  _Move(this.when, this.name, this.service, {this.therapist});
  final String when;
  final String name;
  final String service;
  String? therapist;
}

/// KS-08 Pindah sesi massal (terapis cuti / berhalangan, §6.3). Pasien diberi tahu via WhatsApp.
class PindahMassalPage extends StatefulWidget {
  const PindahMassalPage({super.key});

  @override
  State<PindahMassalPage> createState() => _PindahMassalPageState();
}

class _PindahMassalPageState extends State<PindahMassalPage> {
  final _moves = [
    _Move(
      'Sel 14 Okt · 09.00',
      'Rina Setiawati',
      'Masase cedera ringan',
      therapist: 'Fajar',
    ),
    _Move(
      'Sel 14 Okt · 13.00',
      'Budi Hartono',
      'Home visit · Relaksasi Premium',
      therapist: 'Laras',
    ),
    _Move(
      'Rab 15 Okt · 10.30',
      'Andi Pratama',
      'Adjustment Therapy · tidak ada terapis kosong',
    ),
  ];
  bool _notify = true;

  Future<void> _pickTherapist(_Move m) async {
    final pick = await context.feedback.sheet<String>(
      title: 'Pilih terapis',
      message: '${m.name} · ${m.when}',
      actions: const [
        SheetAction(
          'Fajar · slot kosong',
          'Fajar',
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Laras · slot kosong',
          'Laras',
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Rudi · slot kosong',
          'Rudi',
          variant: OlButtonVariant.secondary,
        ),
      ],
    );
    if (pick != null) setState(() => m.therapist = pick);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final ready = _moves.where((m) => m.therapist != null).length;
    return OlDetailScaffold(
      title: 'Pindahkan ${_moves.length} sesi',
      context_: 'Dimas cuti 14–15 Okt (disetujui)',
      foot: [
        OlButton(
          label: 'Simpan $ready perpindahan',
          onPressed: ready == 0
              ? null
              : () {
                  context.feedback.success(
                    '$ready sesi dipindah.${_notify ? ' Pasien diberi tahu via WhatsApp.' : ''}',
                  );
                  Navigator.of(context).maybePop();
                },
        ),
      ],
      children: [
        for (final m in _moves)
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.when,
                        style: t.mono.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    m.therapist != null
                        ? const OlTag('Siap', tone: OlTagTone.ok)
                        : const OlTag('Perlu tindakan', tone: OlTagTone.crit),
                  ],
                ),
                const SizedBox(height: 6),
                Text(m.name, style: t.heading),
                Text(m.service, style: t.body.copyWith(color: c.muted)),
                const SizedBox(height: 10),
                if (m.therapist != null)
                  Semantics(
                    container: true,
                    button: true,
                    label:
                        'Terapis: ${m.therapist}, slot kosong. Ketuk untuk mengganti',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => _pickTherapist(m),
                      borderRadius: BorderRadius.circular(OlRadius.input),
                      child: Container(
                        height: OlSize.input,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(OlRadius.input),
                          border: Border.all(color: c.line, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Terapis: ',
                                      style: TextStyle(color: c.muted),
                                    ),
                                    TextSpan(
                                      text: m.therapist,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const TextSpan(text: ' · slot kosong'),
                                  ],
                                ),
                                style: t.body.copyWith(fontSize: 15),
                              ),
                            ),
                            OlIcon(
                              OlIcons.chevronDown,
                              size: 18,
                              color: c.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  OlFootRow(
                    children: [
                      OlButton.secondary(
                        label: 'Pindah jam',
                        small: true,
                        onPressed: () => context.feedback.info(
                          'Pilih jam baru di Buat jadwal.',
                        ),
                      ),
                      OlButton.secondary(
                        label: 'Pilih terapis',
                        small: true,
                        onPressed: () => _pickTherapist(m),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OlCheckbox(
                label: 'Beri tahu pasien via WhatsApp',
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(
                  '"Sesi Anda dipindah ke terapis Fajar, jam tetap…"',
                  style: t.body.copyWith(color: c.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
