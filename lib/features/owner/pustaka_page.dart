import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Area { all, ankle, knee, back, proposed }

class _Exercise {
  _Exercise(this.name, this.area, this.meta, {this.proposedBy});
  final String name;
  final _Area area;
  final String meta;
  String? proposedBy;
}

const _areaLabels = {
  _Area.ankle: 'Ankle & kaki',
  _Area.knee: 'Lutut',
  _Area.back: 'Punggung',
};

/// OW-15 Pustaka latihan: daftar latihan per area, setujui usulan terapis,
/// tambah latihan dengan video.
class PustakaPage extends StatefulWidget {
  const PustakaPage({super.key});

  @override
  State<PustakaPage> createState() => _PustakaPageState();
}

class _PustakaPageState extends State<PustakaPage> {
  _Area _filter = _Area.all;
  final _items = [
    _Exercise('Calf raise', _Area.ankle, 'Ankle · pemula · 3×12'),
    _Exercise('Ankle alphabet', _Area.ankle, 'Ankle · pemula · 2 set'),
    _Exercise('Cat–cow', _Area.back, 'Punggung · 2×10'),
    _Exercise('Bird dog', _Area.back, 'Punggung · 2×8', proposedBy: 'Fajar'),
    _Exercise('Wall sit', _Area.knee, 'Lutut · menengah · 3×30 dtk'),
    _Exercise(
      'Straight leg raise',
      _Area.knee,
      'Lutut · pemula · 3×10',
      proposedBy: 'Laras',
    ),
  ];
  final _name = TextEditingController(text: 'Single-leg stand');
  _Area _area = _Area.ankle;
  String? _video;
  final _formKey = GlobalKey();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _open(_Exercise e) async {
    if (e.proposedBy == null) {
      await context.feedback.sheet<void>(
        title: e.name,
        message: e.meta,
        actions: const [
          SheetAction('Tutup', null, variant: OlButtonVariant.secondary),
        ],
      );
      return;
    }
    final ok = await context.feedback.sheet<bool>(
      title: 'Usulan ${e.proposedBy}: ${e.name}',
      message: '${e.meta}. Setujui agar bisa dipakai semua terapis.',
      actions: const [
        SheetAction('Setujui', true),
        SheetAction('Tolak', false, variant: OlButtonVariant.dangerSecondary),
      ],
    );
    if (ok == null || !mounted) return;
    setState(() {
      if (ok) {
        e.proposedBy = null;
      } else {
        _items.remove(e);
      }
    });
    context.feedback.success(
      ok ? '${e.name} masuk pustaka.' : 'Usulan ditolak.',
    );
  }

  void _save() {
    setState(() {
      _items.add(_Exercise(_name.text.trim(), _area, '${_areaLabels[_area]}'));
      _name.clear();
      _video = null;
    });
    context.feedback.success('Latihan ditambahkan ke pustaka.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final proposed = _items.where((e) => e.proposedBy != null).length;
    final rows = _items.where((e) {
      return switch (_filter) {
        _Area.all => true,
        _Area.proposed => e.proposedBy != null,
        final a => e.area == a,
      };
    }).toList();

    return OlDetailScaffold(
      title: 'Pustaka latihan',
      context_: '48 latihan · $proposed usulan terapis',
      actions: [
        OlButton(
          label: '+ Latihan',
          small: true,
          expand: false,
          onPressed: () => Scrollable.ensureVisible(
            _formKey.currentContext!,
            duration: OlMotion.of(context, OlMotion.slow),
            curve: OlMotion.curve,
          ),
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (a, l) in [
              (_Area.all, 'Semua'),
              for (final e in _areaLabels.entries) (e.key, e.value),
              (_Area.proposed, 'Usulan · $proposed'),
            ])
              OlChip(
                label: l,
                selected: _filter == a,
                onTap: () => setState(() => _filter = a),
              ),
          ],
        ),
        OlTwoColumnGrid(
          children: [
            for (final e in rows)
              OlCard(
                key: ValueKey(e.name),
                padding: const EdgeInsets.all(10),
                onTap: () => _open(e),
                semanticLabel:
                    '${e.name}, ${e.meta}${e.proposedBy == null ? '' : ', usulan ${e.proposedBy}'}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.55,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: e.proposedBy != null
                              ? const Color(0xFF5B6B79)
                              : null,
                          gradient: e.proposedBy != null
                              ? null
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [c.brandDeep, c.brand],
                                ),
                        ),
                        child: const OlPlayGlyph(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(e.name, style: t.bodyStrong.copyWith(fontSize: 15)),
                    const SizedBox(height: 4),
                    if (e.proposedBy != null)
                      OlTag('Usulan ${e.proposedBy}', tone: OlTagTone.warn)
                    else
                      Text(
                        e.meta,
                        style: t.body.copyWith(fontSize: 13.5, color: c.muted),
                      ),
                  ],
                ),
              ),
          ],
        ),
        OlOverline('LATIHAN BARU', key: _formKey),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OlTextField(
                label: 'Nama',
                isRequired: true,
                controller: _name,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: OlSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: OlSelectField<_Area>(
                      label: 'Area',
                      isRequired: true,
                      sheetTitle: 'Area tubuh',
                      value: _area,
                      options: _areaLabels,
                      onChanged: (v) => setState(() => _area = v),
                    ),
                  ),
                  const SizedBox(width: OlSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Video', style: t.fieldLabel),
                        const SizedBox(height: 8),
                        OlButton.secondary(
                          label: _video ?? 'Unggah (maks 50 MB)',
                          icon: _video == null ? OlIcons.upload : OlIcons.check,
                          onPressed: () =>
                              setState(() => _video = 'single_leg.mp4'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              OlButton(
                label: 'Simpan latihan',
                onPressed: _name.text.trim().isEmpty ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
