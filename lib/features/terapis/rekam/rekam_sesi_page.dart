import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/api/one_lotus_api.dart';
import '../../../data/auth/auth_controller.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../../data/sync/outbox.dart' show newId;
import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/body_map/body_map.dart';
import '../../../ui/ui.dart';

/// TR-04 Rekam sesi (layar prioritas §5.2). Data sesi & peringatan medis dari server; isian
/// dilanjutkan dari draf di HP, rekam yang sudah ada, atau diisi awal dari rekam terakhir pasien.
/// Simpan masuk outbox (aman offline, §8); "Selesaikan sesi" juga mengubah status ke Selesai.
class RekamSesiPage extends ConsumerStatefulWidget {
  const RekamSesiPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<RekamSesiPage> createState() => _RekamSesiPageState();
}

class _RekamSesiPageState extends ConsumerState<RekamSesiPage> {
  final _complaint = TextEditingController();
  final _analysis = TextEditingController();
  final _conclusion = TextEditingController();
  final _injury = TextEditingController();
  BodyMode _mode = BodyMode.treated;
  var _areas = const BodyMapSelection();
  int? _before;
  int? _after;
  InjuryCause? _cause;
  DurationUnit _unit = DurationUnit.week;
  final _analysisTags = <String>{};
  final _treatments = <String>{};
  final _conclusionTags = <String>{};
  bool _dirty = false;
  bool _saving = false;
  String? _areaError;
  String? _treatmentError;
  String? _complaintError;

  Session? _session;
  Patient? _patient;
  SessionRecord? _existing;
  bool _prefilled = false;
  AppError? _loadError;
  Timer? _clock;
  Timer? _draftTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _draftTimer?.cancel();
    for (final c in [_complaint, _analysis, _conclusion, _injury]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    final repo = ref.read(sessionRecordRepositoryProvider);
    final api = ref.read(oneLotusApiProvider);
    try {
      final session = await api.session(widget.sessionId);
      Patient? patient;
      try {
        patient = await api.patient(session.patientId);
      } on AppError {
        patient = null; // peringatan medis opsional; rekam tetap bisa diisi
      }
      final draft = await repo.loadDraft(widget.sessionId);
      final existing = draft ?? await repo.forSession(widget.sessionId);
      final source = existing ?? await repo.latestForPatient(session.patientId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _patient = patient;
        _existing = existing;
        _prefilled = existing == null && source != null;
        if (source != null) _fill(source, full: existing != null);
      });
      final started = session.startedAt;
      if (session.status == SessionStatus.running && started != null) {
        _elapsed = DateTime.now().difference(started);
        _clock = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
        });
      }
    } on AppError catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  /// [full] = isi semua field (draf / rekam sesi ini); selain itu hanya prefill dari sesi lalu (§5.2).
  void _fill(SessionRecord r, {required bool full}) {
    _complaint.text = r.complaint;
    _cause = r.cause;
    _injury.text = r.injuryDuration?.toString() ?? '';
    _unit = r.injuryDurationUnit ?? DurationUnit.week;
    if (!full) return;
    _areas = BodyMapSelection({
      for (final a in r.treatedAreas) a: BodyMode.treated,
      for (final a in r.calmingAreas) a: BodyMode.calming,
    });
    _before = r.painBefore;
    _after = r.painAfter;
    _analysis.text = r.analysis;
    _analysisTags.addAll(r.analysisTags);
    _treatments.addAll(r.treatments);
    _conclusion.text = r.conclusion;
    _conclusionTags.addAll(r.conclusionTags);
  }

  SessionRecord _record() {
    final s = _session!;
    return SessionRecord(
      id: _existing?.id ?? newId(),
      sessionId: s.id,
      patientId: s.patientId,
      therapistId: ref.read(authProvider).user?.id ?? s.therapistId,
      complaint: _complaint.text.trim(),
      cause: _cause,
      injuryDuration: int.tryParse(_injury.text.trim()),
      injuryDurationUnit: _injury.text.trim().isEmpty ? null : _unit,
      treatedAreas: _areas.keysOf(BodyMode.treated),
      calmingAreas: _areas.keysOf(BodyMode.calming),
      painBefore: _before,
      painAfter: _after,
      analysis: _analysis.text.trim(),
      analysisTags: _analysisTags.toList(),
      treatments: _treatments.toList(),
      conclusion: _conclusion.text.trim(),
      conclusionTags: _conclusionTags.toList(),
      attachments: _existing?.attachments ?? const [],
      version: _existing?.version ?? 0,
    );
  }

  /// Draf otomatis di HP (§5.2) — tidak dikirim ke server sampai disimpan.
  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 800), () {
      if (_session != null) {
        unawaited(
          ref.read(sessionRecordRepositoryProvider).saveDraft(_record()),
        );
      }
    });
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

  Future<void> _save({bool finish = false}) async {
    if (!_validate()) {
      context.feedback.info('Lengkapi isian yang ditandai dulu.');
      return;
    }
    setState(() => _saving = true);
    _draftTimer?.cancel();
    try {
      final record = _record();
      await ref.read(sessionRecordRepositoryProvider).submit(record);
      _existing = record;
      if (finish && _session!.status == SessionStatus.running) {
        await ref
            .read(scheduleRepositoryProvider)
            .updateStatus(_session!, SessionStatus.done);
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _saving = false;
        _dirty = false;
      });
      context.feedback.success(
        finish
            ? 'Sesi selesai & tersimpan. Terkirim otomatis saat ada sinyal.'
            : 'Sesi tersimpan. Terkirim otomatis saat ada sinyal.',
      );
      if (finish) context.go(Routes.terapisJadwal);
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.feedback.error(e, retry: () => _save(finish: finish));
    }
  }

  /// §12.5: keluar dari rekam sesi yang belum disimpan (draf tetap tersimpan di HP).
  Future<void> _onLeave() async {
    final r = await context.feedback.choose(
      const ConfirmSpec(
        title: 'Simpan dulu catatan ini?',
        message: 'Ada perubahan yang belum disimpan. Draf tetap ada di HP.',
        confirmLabel: 'Simpan',
        danger: false,
        alternativeLabel: 'Buang perubahan',
      ),
    );
    if (!mounted) return;
    switch (r.choice) {
      case ConfirmChoice.confirm:
        await _save();
        if (mounted && !_dirty) Navigator.of(context).pop();
      case ConfirmChoice.alternative:
        await ref
            .read(sessionRecordRepositoryProvider)
            .deleteDraft(widget.sessionId);
        if (mounted) Navigator.of(context).pop();
      case ConfirmChoice.cancel:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final session = _session;
    if (session == null) {
      return OlDetailScaffold(
        title: 'Rekam sesi',
        children: [
          if (_loadError != null)
            OlErrorCard(
              message: _loadError!.message,
              refId: _loadError!.refId,
              onRetry: _load,
            )
          else
            const OlLoadingCard(),
        ],
      );
    }
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
        title: session.patientName,
        context_: [
          Fmt.patientNo(session.patientNumber),
          session.serviceName,
          if (session.isHomeVisit) 'home visit' else ?session.room,
        ].join(' · '),
        actions: [
          SyncIndicator(
            status: _dirty ? const SyncSaving() : const SyncSynced(),
            label: _dirty
                ? 'Menyimpan draf…'
                : 'Tersimpan di HP · sinkron otomatis',
          ),
        ],
        titleTrailing: _clock == null
            ? null
            : Semantics(
                label: 'Durasi sesi $m menit $s detik',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
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
            label: session.status == SessionStatus.running
                ? 'Simpan & selesaikan sesi'
                : 'Simpan',
            loading: _saving,
            onPressed: _saving
                ? null
                : () => _save(finish: session.status == SessionStatus.running),
          ),
          if (session.status == SessionStatus.running)
            OlButton.secondary(
              label: 'Simpan saja',
              onPressed: _saving ? null : () => _save(),
            ),
        ],
        children: [
          if (_patient?.medicalAlert != null)
            OlBanner(tone: OlBannerTone.crit, message: _patient!.medicalAlert!),
          OlTextField(
            label: 'Keluhan',
            isRequired: true,
            controller: _complaint,
            helper: _prefilled
                ? 'Diisi dari sesi lalu · ketuk untuk ubah'
                : null,
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
                    _SelectField<InjuryCause?>(
                      value: _cause,
                      options: {
                        null: 'Pilih',
                        for (final c in InjuryCause.values) c: c.label,
                      },
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
