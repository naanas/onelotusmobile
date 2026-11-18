import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/body_map/body_map_selection.dart';
import '../../ui/ui.dart';
import 'recovery_body.dart';

/// Ringkasan perjalanan pemulihan pasien di Beranda.
/// Sumber: sesi selesai (`GET /v1/patient/sessions`, skor nyeri) dan program latihan
/// (`GET /v1/patient/exercises`, tanggal program + kepatuhan minggu ini).
/// Belum ada aktivitas / gagal dimuat → semua nilai 0 dan tahapan "belum dimulai".
class RecoveryJourneyCard extends ConsumerStatefulWidget {
  const RecoveryJourneyCard({super.key});

  @override
  ConsumerState<RecoveryJourneyCard> createState() =>
      _RecoveryJourneyCardState();
}

class _RecoveryJourneyCardState extends ConsumerState<RecoveryJourneyCard> {
  late Future<RecoveryJourney> _future = _load();
  late final AppLifecycleListener _life;
  DateTime _loadedAt = DateTime.now();
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: () {
      if (_visible) _refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kembali ke tab Beranda / dari layar lain → muat ulang diam-diam (data lama tetap tampil).
    final visible = TickerMode.of(context);
    if (visible && !_visible) _refresh(inBuild: true);
    _visible = visible;
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  /// [inBuild]: dipanggil dari didChangeDependencies — widget memang akan dibangun ulang, tanpa setState.
  void _refresh({bool inBuild = false}) {
    if (!mounted || DateTime.now().difference(_loadedAt) < const Duration(seconds: 2)) return;
    _loadedAt = DateTime.now();
    final prev = _future;
    // Gagal → tetap pakai hasil sebelumnya.
    final next = _load().catchError((Object _) => prev);
    if (inBuild) {
      _future = next;
    } else {
      setState(() {
        _future = next;
      });
    }
  }

  Future<RecoveryJourney> _load() async {
    final api = ref.read(pasienAppApiProvider);
    final results = await Future.wait<List<Object>>([
      api.sessions().catchError((_) => <PatientSessionV>[]),
      api.programs().catchError((_) => <ProgramV>[]),
    ]);
    final sessions = results[0].cast<PatientSessionV>();
    // Area tubuh hanya ada di detail sesi: ambil dari sesi selesai terakhir.
    var areas = const <String, String>{};
    if (sessions.isNotEmpty) {
      final last = sessions.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
      areas = await api
          .sessionAreas(last.sessionId)
          .catchError((_) => const <String, String>{});
    }
    return RecoveryJourney.from(
      sessions: sessions,
      programs: results[1].cast<ProgramV>(),
      areas: areas,
      now: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlCard(
      child: FutureBuilder<RecoveryJourney>(
        future: _future,
        builder: (context, snap) {
          final j = snap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Perjalanan pemulihan', style: t.heading),
              Text(
                'Pantau progres terapi Anda menuju pulih.',
                style: t.caption.copyWith(color: c.muted),
              ),
              const SizedBox(height: OlSpace.lg),
              if (j == null)
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Skeleton(height: 250),
                    SizedBox(height: OlSpace.lg),
                    Skeleton(height: 96),
                    SizedBox(height: OlSpace.lg),
                    Skeleton(height: 160),
                  ],
                )
              else ...[
                RecoveryBody(areas: j.areas, labels: j.highlights),
                const SizedBox(height: OlSpace.lg),
                _Stats(j),
                const SizedBox(height: OlSpace.lg),
                _Timeline(j.stages),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---- model ----

enum StageState { done, active, pending }

class RecoveryStage {
  const RecoveryStage(this.title, this.subtitle, this.state);
  final String title, subtitle;
  final StageState state;
}

class RecoveryJourney {
  const RecoveryJourney({
    required this.pain,
    required this.painDropPct,
    required this.programPct,
    required this.adherencePct,
    required this.stages,
    this.areas = const {},
  });

  /// Area tubuh yang ditangani di sesi terakhir (`slug:sisi` → mode).
  final Map<String, BodyMode> areas;

  /// Skor nyeri terakhir (0–10).
  final int pain;

  /// Penurunan nyeri dibanding sesi pertama, dalam persen (0 bila belum ada / naik).
  final int painDropPct;

  /// Persentase waktu program latihan yang sudah berjalan.
  final int programPct;

  /// Kepatuhan latihan minggu ini.
  final int adherencePct;
  final List<RecoveryStage> stages;

  /// Label melayang di peta tubuh.
  List<({String text, bool? down})> get highlights => [
    if (painDropPct > 0) (text: 'Nyeri berkurang $painDropPct%', down: true),
    if (adherencePct > 0) (text: 'Latihan $adherencePct%', down: false),
  ];

  factory RecoveryJourney.from({
    required List<PatientSessionV> sessions,
    required List<ProgramV> programs,
    required DateTime now,
    Map<String, String> areas = const {},
  }) {
    final done = [...sessions]..sort((a, b) => a.date.compareTo(b.date));

    // Nyeri: sesi pertama (sebelum terapi) vs sesi terakhir (setelah terapi).
    var pain = 0, drop = 0;
    final scored = [
      for (final s in done)
        if ((s.painAfter ?? s.painBefore) != null) s,
    ];
    if (scored.isNotEmpty) {
      final last = scored.last;
      pain = last.painAfter ?? last.painBefore!;
      final start = scored.first.painBefore ?? scored.first.painAfter!;
      if (start > 0 && pain < start) {
        drop = ((start - pain) * 100 / start).round();
      }
    }

    // Program: yang aktif, kalau tidak ada yang terbaru.
    final sorted = [...programs]
      ..sort(
        (a, b) =>
            (a.startsOn ?? DateTime(0)).compareTo(b.startsOn ?? DateTime(0)),
      );
    final active = sorted.where((p) => p.status == 'active').lastOrNull;
    final program = active ?? sorted.lastOrNull;
    final finished = program != null && program.status != 'active';

    var programPct = 0;
    int? week, weeks;
    final start = program?.startsOn, end = program?.endsOn;
    if (start != null) {
      final elapsed = now.difference(start).inDays;
      week = math.max(1, elapsed ~/ 7 + 1);
      if (end != null && end.isAfter(start)) {
        final total = end.difference(start).inDays;
        weeks = math.max(1, (total / 7).ceil());
        week = math.min(week, weeks);
        programPct = (elapsed * 100 / total).round().clamp(0, 100);
      }
    }
    if (finished) programPct = 100;
    final secondHalf = programPct >= 50;

    final stages = [
      RecoveryStage(
        'Asesmen awal',
        done.isEmpty ? 'Belum dimulai' : Fmt.dateNoDay(done.first.date),
        done.isEmpty ? StageState.pending : StageState.done,
      ),
      RecoveryStage(
        'Rencana terapi',
        program == null
            ? 'Menunggu terapis'
            : start == null
            ? 'Sudah dibuat'
            : Fmt.dateNoDay(start),
        program == null ? StageState.pending : StageState.done,
      ),
      RecoveryStage(
        'Rehabilitasi aktif',
        active == null
            ? (finished ? 'Selesai' : 'Belum dimulai')
            : weeks == null
            ? 'Berjalan · minggu ${week ?? 1}'
            : 'Berjalan · minggu $week dari $weeks',
        finished || (active != null && secondHalf)
            ? StageState.done
            : active != null
            ? StageState.active
            : StageState.pending,
      ),
      RecoveryStage(
        'Penguatan & mobilitas',
        finished
            ? 'Selesai'
            : (active != null && secondHalf ? 'Berjalan' : 'Belum dimulai'),
        finished
            ? StageState.done
            : active != null && secondHalf
            ? StageState.active
            : StageState.pending,
      ),
      RecoveryStage(
        'Pulih penuh',
        finished
            ? 'Program selesai'
            : end == null
            ? 'Belum ada perkiraan'
            : 'Perkiraan ${Fmt.dateNoDay(end)}',
        finished ? StageState.done : StageState.pending,
      ),
    ];

    return RecoveryJourney(
      pain: pain,
      painDropPct: drop,
      programPct: programPct,
      adherencePct: (active?.adherence ?? 0).clamp(0, 100),
      stages: stages,
      areas: {
        for (final e in areas.entries)
          e.key: e.value == 'calming' ? BodyMode.calming : BodyMode.treated,
      },
    );
  }
}

// ---- tampilan ----

class _Stats extends StatelessWidget {
  const _Stats(this.j);
  final RecoveryJourney j;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _StatTile(
          icon: OlIcons.pain,
          label: 'Tingkat nyeri',
          value: '${j.pain}',
          unit: '/10',
          delta: j.painDropPct > 0 ? '↓ ${j.painDropPct}%' : null,
        ),
      ),
      const SizedBox(width: OlSpace.sm),
      Expanded(
        child: _StatTile(
          icon: OlIcons.chart,
          label: 'Progres terapi',
          value: '${j.programPct}%',
        ),
      ),
      const SizedBox(width: OlSpace.sm),
      Expanded(
        child: _StatTile(
          icon: OlIcons.exercise,
          label: 'Latihan rutin',
          value: '${j.adherencePct}%',
        ),
      ),
    ],
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.delta,
  });

  final OlIconData icon;
  final String label, value;
  final String? unit, delta;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      padding: const EdgeInsets.all(OlSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(OlRadius.input),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c.brandSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: OlIcon(icon, size: 16, color: c.brand),
          ),
          const SizedBox(height: OlSpace.sm),
          Text(label, style: t.caption.copyWith(color: c.muted), maxLines: 2),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                style: t.title,
                children: [
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: t.caption.copyWith(color: c.muted),
                    ),
                ],
              ),
            ),
          ),
          if (delta != null)
            Text(
              delta!,
              style: t.caption.copyWith(
                color: c.ok,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.stages);
  final List<RecoveryStage> stages;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < stages.length; i++)
        _StageRow(
          stage: stages[i],
          last: i == stages.length - 1,
          nextDone:
              i < stages.length - 1 &&
              stages[i + 1].state != StageState.pending,
        ),
    ],
  );
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.last,
    required this.nextDone,
  });
  final RecoveryStage stage;
  final bool last, nextDone;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final (Color dot, Color ring, Widget? inner) = switch (stage.state) {
      StageState.done => (
        c.ok,
        c.okSoft,
        OlIcon(OlIcons.check, size: 14, color: Colors.white),
      ),
      StageState.active => (
        c.warn,
        c.warnSoft,
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
      StageState.pending => (c.line, c.surfaceAlt, null),
    };
    final titleColor = stage.state == StageState.active ? c.warn : c.fg;
    final subColor = stage.state == StageState.active ? c.warn : c.muted;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: ring,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: inner,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: nextDone ? c.ok.withValues(alpha: .5) : c.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: OlSpace.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: last ? 0 : OlSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.title,
                    style: t.bodyStrong.copyWith(color: titleColor),
                  ),
                  Text(
                    stage.subtitle,
                    style: t.caption.copyWith(color: subColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
