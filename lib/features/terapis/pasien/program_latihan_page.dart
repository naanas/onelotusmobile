import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/api/billing_api.dart';
import '../../../data/models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/body_map/body_map_selection.dart';
import '../../../ui/ui.dart';
import '../../kasir/billing_common.dart';

/// Dosis satu latihan di program yang sedang disusun.
class _Dose {
  _Dose(ExerciseV e)
    : sets = e.sets,
      reps = e.reps,
      durationSec = e.durationSec;
  int? sets, reps, durationSec;
  int perDay = 1;

  String get label => [
    if (sets != null && reps != null)
      '$sets × $reps'
    else if (durationSec != null)
      '$durationSec detik',
    '$perDay×/hari',
  ].join(' · ');
}

/// TR-13 Kirim program latihan (Fase 3): pustaka per area tubuh, atur set/repetisi, kirim ke app pasien.
class ProgramLatihanPage extends ConsumerStatefulWidget {
  const ProgramLatihanPage({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<ProgramLatihanPage> createState() => _ProgramLatihanPageState();
}

class _ProgramLatihanPageState extends ConsumerState<ProgramLatihanPage> {
  BillingApi get _api => ref.read(billingApiProvider);
  late Future<(List<ExerciseV>, List<ProgramV>)> _future = _load();

  Future<(List<ExerciseV>, List<ProgramV>)> _load() =>
      (_api.exercises(), _api.programs(widget.patientId)).wait;

  String? _area;
  final _picked = <String, _Dose>{};
  int _weeks = 2;
  final _note = TextEditingController();
  bool _busy = false;

  Future<void> _editDose(ExerciseV e) async {
    final d = _picked[e.id]!;
    final sets = TextEditingController(text: d.sets?.toString() ?? '');
    final reps = TextEditingController(text: d.reps?.toString() ?? '');
    final dur = TextEditingController(text: d.durationSec?.toString() ?? '');
    var perDay = d.perDay;
    final ok = await formSheet(
      context,
      title: e.name,
      message: 'Isi set × repetisi, atau durasi untuk latihan tahan.',
      fields: (set) => [
        Row(
          children: [
            Expanded(
              child: OlTextField(
                label: 'Set',
                controller: sets,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: OlTextField(
                label: 'Repetisi',
                controller: reps,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        OlTextField(
          label: 'Durasi (detik)',
          controller: dur,
          keyboardType: TextInputType.number,
        ),
        OlSegmented<int>(
          segments: const {1: '1×/hari', 2: '2×/hari', 3: '3×/hari'},
          value: perDay,
          onChanged: (v) => set(() => perDay = v),
        ),
      ],
    );
    if (!ok) return;
    int? n(TextEditingController c) =>
        c.text.trim().isEmpty ? null : parseAmount(c.text);
    setState(() {
      d
        ..sets = n(sets)
        ..reps = n(reps)
        ..durationSec = n(dur)
        ..perDay = perDay;
    });
  }

  Future<void> _send() async {
    final today = DateTime.now();
    String day(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    setState(() => _busy = true);
    final p = await runApi(
      context,
      () => _api.sendProgram(widget.patientId, {
        'starts_on': day(today),
        'ends_on': day(today.add(Duration(days: 7 * _weeks - 1))),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'items': [
          for (final MapEntry(key: id, value: d) in _picked.entries)
            {
              'exercise_id': id,
              'sets': d.sets,
              'reps': d.reps,
              'duration_sec': d.durationSec,
              'per_day': d.perDay,
            },
        ],
      }),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (p == null) return;
    context.feedback.success('Program dikirim ke aplikasi pasien.');
    context.pop();
  }

  /// Tarik-untuk-memuat-ulang: data lama tetap tampil sampai data baru datang.
  Future<void> _pullRefresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
    return next;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _future,
    builder: (context, snap) {
      final c = context.ol;
      final t = context.olText;
      final data = snap.data;
      final library = [
        for (final e in data?.$1 ?? const <ExerciseV>[])
          if (e.status == 'approved') e,
      ];
      final areas = {for (final e in library) ...e.areas}.toList()..sort();
      final shown = [
        for (final e in library)
          if (_area == null || e.areas.contains(_area)) e,
      ];
      final active = [
        for (final p in data?.$2 ?? const <ProgramV>[])
          if (p.status == 'active') p,
      ];
      return OlDetailScaffold(
        onRefresh: _pullRefresh,
        title: 'Kirim program latihan',
        foot: [
          if (_picked.isNotEmpty)
            OlButton(
              label: 'Kirim ${_picked.length} latihan',
              icon: OlIcons.send,
              loading: _busy,
              onPressed: _send,
            ),
        ],
        children: [
          if (snap.hasError)
            OlErrorCard(
              message: snap.error is AppError
                  ? (snap.error as AppError).message
                  : 'Pustaka latihan belum bisa dimuat.',
              onRetry: () => setState(() {
                _future = _load();
              }),
            )
          else if (data == null)
            const OlLoadingCard()
          else ...[
            if (active.isNotEmpty)
              OlBanner(
                message:
                    'Pasien punya ${active.length} program aktif'
                    '${active.first.endsOn == null ? '' : ' sampai ${Fmt.dayShort(active.first.endsOn!)}'}'
                    ' · kepatuhan minggu ini ${active.first.adherence}%.',
                tone: OlBannerTone.info,
              ),
            if (areas.isNotEmpty)
              Wrap(
                spacing: OlSpace.sm,
                runSpacing: OlSpace.sm,
                children: [
                  OlChip(
                    label: 'Semua area',
                    small: true,
                    selected: _area == null,
                    onTap: () => setState(() => _area = null),
                  ),
                  for (final a in areas)
                    OlChip(
                      label: bodyAreaNames[a] ?? a,
                      small: true,
                      selected: _area == a,
                      onTap: () => setState(() => _area = a),
                    ),
                ],
              ),
            if (shown.isEmpty)
              const OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptyInbox,
                  title: 'Pustaka latihan kosong',
                  message: 'Owner menambah latihan di menu Pustaka latihan.',
                ),
              )
            else
              OlCard(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                child: Column(
                  children: [
                    for (final e in shown)
                      OlCheckbox(
                        label: e.name,
                        subtitle:
                            _picked[e.id]?.label ??
                            [
                              for (final a in e.areas) bodyAreaNames[a] ?? a,
                            ].join(', '),
                        value: _picked.containsKey(e.id),
                        onChanged: (v) => setState(
                          () => v
                              ? _picked[e.id] = _Dose(e)
                              : _picked.remove(e.id),
                        ),
                      ),
                  ],
                ),
              ),
            if (_picked.isNotEmpty) ...[
              const OlSectionHeader(title: 'Dosis'),
              OlCard(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                child: Column(
                  children: [
                    for (final (n, e)
                        in library
                            .where((e) => _picked.containsKey(e.id))
                            .indexed)
                      OlListItem(
                        title: e.name,
                        subtitle: _picked[e.id]!.label,
                        trailing: OlIcon(OlIcons.edit, color: c.muted),
                        divider: n < _picked.length - 1,
                        onTap: () => _editDose(e),
                      ),
                  ],
                ),
              ),
              OlSegmented<int>(
                segments: const {1: '1 minggu', 2: '2 minggu', 4: '4 minggu'},
                value: _weeks,
                onChanged: (w) => setState(() => _weeks = w),
              ),
              OlTextField(
                label: 'Catatan untuk pasien',
                controller: _note,
                maxLines: 3,
              ),
              Text(
                'Pasien menerima notifikasi dan bisa menandai latihan selesai tiap hari.',
                style: t.caption.copyWith(color: c.muted),
              ),
            ],
          ],
        ],
      );
    },
  );
}
