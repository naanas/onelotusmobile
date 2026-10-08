import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/session_record.dart';
import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/body_map/body_map.dart';
import '../../../ui/ui.dart';

/// TR-04 Rekam sesi (layar prioritas §5.2). Slicing UI: isian awal = prefill dari sesi lalu (contoh mockup).
class RekamSesiPage extends StatefulWidget {
  const RekamSesiPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<RekamSesiPage> createState() => _RekamSesiPageState();
}

class _RekamSesiPageState extends State<RekamSesiPage> {
  // Prefill dari sesi lalu (§5.2).
  final _complaint = TextEditingController(
    text: 'Nyeri pinggang bawah menjalar ke paha kanan',
  );
  final _analysis = TextEditingController(
    text: 'Ketegangan paravertebral kanan, ROM fleksi terbatas.',
  );
  final _conclusion = TextEditingController(
    text: 'Kurangi duduk lama, peregangan tiap 1 jam.',
  );
  final _injury = TextEditingController(text: '3');
  BodyMode _mode = BodyMode.treated;
  var _areas = const BodyMapSelection({
    'lower-back:left': BodyMode.treated,
    'lower-back:right': BodyMode.treated,
    'deltoids:right': BodyMode.treated,
    'upper-back:left': BodyMode.calming,
    'upper-back:right': BodyMode.calming,
    'quadriceps:right': BodyMode.calming,
  });
  int? _before = 7;
  int? _after;
  InjuryCause _cause = InjuryCause.work;
  DurationUnit _unit = DurationUnit.month;
  final _analysisTags = {'Spasme otot', 'Saraf terjepit ringan'};
  final _treatments = {'Adjustment', 'Infrared'};
  final _conclusionTags = {'Kontrol 1 minggu', 'Latihan rumah'};
  int _extraPoints = 1;
  bool _extraInjury = false;
  bool _dirty = false;
  bool _saving = false;
  String? _areaError;
  String? _treatmentError;
  String? _complaintError;

  late final Timer _clock;
  Duration _elapsed = const Duration(minutes: 12, seconds: 40);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    for (final c in [_complaint, _analysis, _conclusion, _injury]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Validasi lunak §5.2: keluhan, area & minimal 1 treatment.
  bool _validate() {
    setState(() {
      _complaintError = _complaint.text.trim().isEmpty
          ? 'Keluhan wajib diisi.'
          : null;
      _areaError = _areas.keysOf(BodyMode.treated).isEmpty
          ? 'Tandai minimal 1 area yang ditangani.'
          : null;
      _treatmentError = _treatments.isEmpty
          ? 'Pilih minimal 1 treatment.'
          : null;
    });
    return _complaintError == null &&
        _areaError == null &&
        _treatmentError == null;
  }

  Future<void> _save({required bool sendSummary, bool finish = false}) async {
    if (!_validate()) {
      context.feedback.info('Lengkapi isian yang ditandai dulu.');
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _saving = false;
      _dirty = false;
    });
    context.feedback.success(
      sendSummary
          ? 'Sesi tersimpan. Ringkasan dikirim ke Andi.'
          : 'Sesi tersimpan.',
    );
    if (finish) {
      context.go(Routes.terapisJadwal);
    } else if (sendSummary) {
      context.pushReplacement(Routes.terapisSesi(widget.sessionId));
    }
  }

  /// §12.5: keluar dari rekam sesi yang belum disimpan.
  Future<void> _onLeave() async {
    final r = await context.feedback.choose(
      const ConfirmSpec(
        title: 'Simpan dulu catatan ini?',
        message: 'Ada perubahan di rekam sesi yang belum disimpan.',
        confirmLabel: 'Simpan',
        danger: false,
        alternativeLabel: 'Buang perubahan',
      ),
    );
    if (!mounted) return;
    switch (r.choice) {
      case ConfirmChoice.confirm:
        await _save(sendSummary: false);
        if (mounted && !_dirty) Navigator.of(context).pop();
      case ConfirmChoice.alternative:
        Navigator.of(context).pop();
      case ConfirmChoice.cancel:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

    Widget label(String text, {bool required = false, String? note}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: text),
            if (note != null)
              TextSpan(
                text: ' $note',
                style: t.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            if (required)
              TextSpan(
                text: ' *',
                style: TextStyle(color: c.crit),
              ),
          ],
        ),
        style: t.fieldLabel,
      ),
    );
    Widget errorText(String? e) => e == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              e,
              style: t.caption.copyWith(
                color: c.crit,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
    Widget tagChips(
      Set<String> selected,
      List<String> options, {
      bool small = true,
    }) => Wrap(
      spacing: 8,
      children: [
        for (final o in options)
          OlChip(
            label: o,
            small: small,
            selected: selected.contains(o),
            onTap: () => setState(() {
              selected.contains(o) ? selected.remove(o) : selected.add(o);
              _dirty = true;
            }),
          ),
      ],
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onLeave();
      },
      child: OlDetailScaffold(
        title: 'Andi Pratama',
        context_: 'Sesi #0412 · Adjustment Therapy · ruang 2',
        actions: [
          SyncIndicator(
            status: _dirty ? const SyncSaving() : const SyncSynced(),
            label: _dirty
                ? 'Menyimpan draf…'
                : 'Tersimpan di HP · sinkron otomatis',
          ),
        ],
        titleTrailing: Semantics(
          label: 'Durasi sesi $m menit $s detik',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: c.brand,
              borderRadius: BorderRadius.circular(OlRadius.pill),
            ),
            child: Text(
              '$m:$s',
              style: t.mono.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        foot: [
          OlButton(
            label: 'Simpan & kirim ringkasan ke pasien',
            loading: _saving,
            onPressed: () => _save(sendSummary: true),
          ),
          OlFootRow(
            children: [
              OlButton.secondary(
                label: 'Simpan saja',
                onPressed: _saving ? null : () => _save(sendSummary: false),
              ),
              OlButton.secondary(
                label: 'Selesaikan sesi',
                onPressed: _saving
                    ? null
                    : () => _save(sendSummary: true, finish: true),
              ),
            ],
          ),
        ],
        children: [
          const OlBanner(
            tone: OlBannerTone.crit,
            message: 'Riwayat LBP kronis — hindari tekanan kuat di L4–L5.',
          ),
          OlTextField(
            label: 'Keluhan',
            isRequired: true,
            controller: _complaint,
            helper: 'Diisi dari sesi lalu · ketuk untuk ubah',
            error: _complaintError,
            onChanged: (_) => _touch(),
          ),
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Area tubuh',
                        style: t.heading.copyWith(fontSize: 17),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: OlSegmented<BodyMode>(
                        segments: const {
                          BodyMode.treated: 'Ditangani',
                          BodyMode.calming: 'Penenang',
                        },
                        value: _mode,
                        onChanged: (v) => setState(() => _mode = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                BodyMap(
                  selection: _areas,
                  mode: _mode,
                  onChanged: (v) => setState(() {
                    _areas = v;
                    _dirty = true;
                    _areaError = null;
                  }),
                ),
                errorText(_areaError),
              ],
            ),
          ),
          OlCard(
            child: PainScale(
              before: _before,
              after: _after,
              onBefore: (v) => setState(() {
                _before = v;
                _dirty = true;
              }),
              onAfter: (v) => setState(() {
                _after = v;
                _dirty = true;
              }),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label('Penyebab'),
                    _SelectField<InjuryCause>(
                      value: _cause,
                      options: {for (final c in InjuryCause.values) c: c.label},
                      onChanged: (v) => setState(() {
                        _cause = v;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label('Lama cedera'),
                    _DurationField(
                      controller: _injury,
                      unit: _unit,
                      onChanged: _touch,
                      onUnit: (u) => setState(() {
                        _unit = u;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label('Analisa terapis', note: '(internal)'),
              tagChips(_analysisTags, const [
                'Spasme otot',
                'Postur buruk',
                'Saraf terjepit ringan',
                '+ Lainnya',
              ]),
              const SizedBox(height: 8),
              OlTextField(
                label: '',
                controller: _analysis,
                maxLines: 3,
                onChanged: (_) => _touch(),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label('Treatment', required: true),
              Wrap(
                spacing: 8,
                children: [
                  for (final (name, icon) in const [
                    ('Adjustment', OlIcons.hands),
                    ('Infrared', OlIcons.infrared),
                    ('Stretching', OlIcons.stretch),
                    ('Kinesio tape', OlIcons.tape),
                    ('Akupuntur', OlIcons.needle),
                  ])
                    OlChip(
                      label: name,
                      icon: icon,
                      selected: _treatments.contains(name),
                      onTap: () => setState(() {
                        _treatments.contains(name)
                            ? _treatments.remove(name)
                            : _treatments.add(name);
                        _dirty = true;
                        _treatmentError = null;
                      }),
                    ),
                ],
              ),
              errorText(_treatmentError),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label('Kesimpulan & saran'),
              tagChips(_conclusionTags, const [
                'Kontrol 1 minggu',
                'Latihan rumah',
                'Kompres hangat',
              ]),
              const SizedBox(height: 8),
              OlTextField(
                label: '',
                controller: _conclusion,
                maxLines: 3,
                onChanged: (_) => _touch(),
              ),
            ],
          ),
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Lampiran', style: t.heading.copyWith(fontSize: 17)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Thumb(
                      dark: true,
                      semanticLabel: 'Foto rontgen lumbal, akses terbatas',
                      child: Text(
                        'Rontgen\nlumbal',
                        textAlign: TextAlign.center,
                        style: t.caption.copyWith(
                          color: const Color(0xFFBAE6FD),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Thumb(
                      semanticLabel: 'Catatan suara 42 detik',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OlIcon(OlIcons.mic, color: c.muted, size: 20),
                          Text(
                            '0:42',
                            style: t.mono.copyWith(
                              fontSize: 12,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Thumb(
                      dashed: true,
                      semanticLabel: 'Tambah lampiran',
                      onTap: () => context.feedback.sheet<void>(
                        title: 'Tambah lampiran',
                        actions: const [
                          SheetAction(
                            'Foto (kamera)',
                            null,
                            variant: OlButtonVariant.secondary,
                          ),
                          SheetAction(
                            'Rontgen (galeri)',
                            null,
                            variant: OlButtonVariant.secondary,
                          ),
                          SheetAction(
                            'Catatan suara',
                            null,
                            variant: OlButtonVariant.secondary,
                          ),
                        ],
                      ),
                      child: OlIcon(OlIcons.plus, color: c.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OlIcon(OlIcons.lock, size: 16, color: c.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Rontgen berlabel akses terbatas',
                        style: t.caption.copyWith(fontSize: 13),
                      ),
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
                Text(
                  'Item tambahan tagihan',
                  style: t.heading.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Titik tambahan',
                        style: t.body.copyWith(fontSize: 15),
                      ),
                    ),
                    _Stepper(
                      value: _extraPoints,
                      onChanged: (v) => setState(() {
                        _extraPoints = v;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tambahan cedera',
                        style: t.body.copyWith(fontSize: 15),
                      ),
                    ),
                    OlToggle(
                      semanticLabel: 'Tambahan cedera',
                      value: _extraInjury,
                      onChanged: (v) => setState(() {
                        _extraInjury = v;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pilihan tunggal berbentuk field (Penyebab) — membuka bottom sheet.
class _SelectField<T> extends StatelessWidget {
  const _SelectField({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Semantics(
      container: true,
      button: true,
      label: 'Penyebab: ${options[value]}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(OlRadius.input),
        onTap: () async {
          final picked = await context.feedback.sheet<T>(
            title: 'Penyebab cedera',
            actions: [
              for (final e in options.entries)
                SheetAction(
                  e.value,
                  e.key,
                  variant: e.key == value
                      ? OlButtonVariant.primary
                      : OlButtonVariant.secondary,
                ),
            ],
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: OlSize.input),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(OlRadius.input),
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  options[value]!,
                  style: t.body.copyWith(fontSize: 15),
                ),
              ),
              OlIcon(OlIcons.chevronDown, size: 18, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.child,
    required this.semanticLabel,
    this.dark = false,
    this.dashed = false,
    this.onTap,
  });

  final Widget child;
  final String semanticLabel;
  final bool dark;
  final bool dashed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: onTap != null,
    label: semanticLabel,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark
              ? const Color(0xFF12344A)
              : (dashed ? Colors.transparent : context.ol.surfaceAlt),
          borderRadius: BorderRadius.circular(14),
          border: dashed
              ? Border.all(color: const Color(0xFFA9BBC9), width: 1.5)
              : null,
        ),
        child: child,
      ),
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    Widget btn(String label, String semantic, VoidCallback? onTap) => Semantics(
      container: true,
      button: true,
      label: semantic,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.ol.line),
            color: context.ol.surface,
          ),
          child: Text(
            label,
            style: t.heading.copyWith(
              color: onTap == null ? context.ol.faint : null,
            ),
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(
          '−',
          'Kurangi titik tambahan',
          value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: t.mono.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        btn('+', 'Tambah titik tambahan', () => onChanged(value + 1)),
      ],
    );
  }
}

/// "Lama cedera": angka + satuan dalam satu kotak (A.2: angka + satuan hari/minggu/bulan/tahun).
class _DurationField extends StatelessWidget {
  const _DurationField({
    required this.controller,
    required this.unit,
    required this.onChanged,
    required this.onUnit,
  });

  final TextEditingController controller;
  final DurationUnit unit;
  final VoidCallback onChanged;
  final ValueChanged<DurationUnit> onUnit;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      height: OlSize.input,
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(OlRadius.input),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              style: t.mono.copyWith(fontSize: 15),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
          Semantics(
            container: true,
            button: true,
            label: 'Satuan: ${unit.label}. Ketuk untuk mengganti',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(OlRadius.input),
              onTap: () async {
                final picked = await context.feedback.sheet<DurationUnit>(
                  title: 'Satuan lama cedera',
                  actions: [
                    for (final u in DurationUnit.values)
                      SheetAction(
                        u.label,
                        u,
                        variant: u == unit
                            ? OlButtonVariant.primary
                            : OlButtonVariant.secondary,
                      ),
                  ],
                );
                if (picked != null) onUnit(picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      unit.label,
                      style: t.body.copyWith(fontSize: 15, color: c.muted),
                    ),
                    const SizedBox(width: 4),
                    OlIcon(OlIcons.chevronDown, size: 16, color: c.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
