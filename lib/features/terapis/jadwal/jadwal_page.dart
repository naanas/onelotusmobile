import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/auth/auth_controller.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';
import '../../shell/role_shell.dart';
import 'jadwal_controller.dart';

/// TR-01 Beranda / Jadwal hari ini (tab Jadwal terapis).
class JadwalPage extends ConsumerStatefulWidget {
  const JadwalPage({super.key});

  @override
  ConsumerState<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends ConsumerState<JadwalPage> {
  Timer? _minute;
  final _runningKey = GlobalKey();
  DateTime? _scrolledFor;

  @override
  void initState() {
    super.initState();
    // "berikutnya dalam n mnt" & banner terlambat diperbarui tiap 30 dtk.
    _minute = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  DateTime get _now => ref.read(clockProvider)();

  /// §5.1: sesi berjalan otomatis di-scroll ke atas layar (sekali per hari yang dibuka).
  void _scrollToRunning(DaySchedule d) {
    if (d.running == null || _scrolledFor == d.day) return;
    _scrolledFor = d.day;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _runningKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        // Hanya bergulir bila kartu berjalan belum terlihat — header & ringkasan tetap tampil.
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: OlMotion.of(context, OlTransitions.page),
        curve: OlMotion.curve,
      );
    });
  }

  Future<void> _afterWrite(String onlineMessage) async {
    if (!mounted) return;
    final offline = ref.read(syncSnapshotProvider).offline;
    if (offline) {
      context.feedback.success(
        'Tersimpan di HP. Akan terkirim saat ada sinyal.',
      );
    } else {
      context.feedback.success(onlineMessage);
    }
  }

  Future<void> _start(DateTime day, Session s) async {
    HapticFeedback.lightImpact();
    await ref.read(therapistScheduleProvider(day).notifier).start(s);
    await _afterWrite('Sesi ${s.patientName} dimulai.');
  }

  Future<void> _more(DateTime day, Session s) async {
    final fb = context.feedback;
    final choice = await fb.sheet<_Action>(
      title: s.patientName,
      message: '${Fmt.time(s.startAt)} · ${s.serviceName}',
      actions: [
        if (s.isHomeVisit)
          const SheetAction(
            'Buka home visit',
            _Action.homeVisit,
            variant: OlButtonVariant.secondary,
          ),
        const SheetAction(
          'Minta pindah jadwal',
          _Action.reschedule,
          variant: OlButtonVariant.secondary,
        ),
        if (s.status == SessionStatus.scheduled ||
            s.status == SessionStatus.arrived)
          const SheetAction(
            'Tandai tidak datang',
            _Action.noShow,
            variant: OlButtonVariant.dangerSecondary,
          ),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _Action.homeVisit:
        unawaited(context.push(Routes.terapisHomeVisit(s.id)));
      case _Action.noShow:
        final r = await fb.choose(
          ConfirmSpec(
            title: 'Tandai ${s.patientName} tidak datang?',
            message:
                'Kasir akan diberi tahu. Status bisa diubah oleh front desk bila pasien ternyata datang.',
            confirmLabel: 'Tandai tidak datang',
            reasonLabel: 'Alasan',
          ),
        );
        if (!r.confirmed) return;
        await ref
            .read(therapistScheduleProvider(day).notifier)
            .markNoShow(s, r.reason!);
        await _afterWrite('${s.patientName} ditandai tidak datang.');
      case _Action.reschedule:
        final req = await fb.formSheet<({String reason, String proposal})>(
          title: 'Minta pindah jadwal',
          message:
              'Permintaan diteruskan ke front desk. Jadwal baru dikonfirmasi oleh kasir.',
          builder: (context, close) => _RescheduleForm(onSubmit: close),
        );
        if (req == null) return;
        await ref
            .read(therapistScheduleProvider(day).notifier)
            .requestReschedule(s, reason: req.reason, proposal: req.proposal);
        await _afterWrite('Permintaan pindah jadwal terkirim ke front desk.');
    }
  }

  void _open(Session s) {
    if (s.status == SessionStatus.running) {
      context.push(Routes.terapisRekam(s.id));
    } else if (s.isFinished) {
      context.push(Routes.terapisSesi(s.id));
    } else if (s.isHomeVisit) {
      context.push(Routes.terapisHomeVisit(s.id));
    } else {
      context.push(Routes.terapisPasienDetail(s.patientId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(selectedDayProvider);
    final async = ref.watch(therapistScheduleProvider(day));
    final filter = ref.watch(scheduleFilterProvider);
    final name = ref.watch(authProvider.select((s) => s.user?.firstName ?? ''));
    final now = _now;
    final schedule = async.value;
    if (schedule != null) _scrollToRunning(schedule);

    final header = OlAppHeader(
      hero: true,
      title: _greeting(now, name),
      context_: headerContext(ref, day),
      actions: [
        OlIconButton(
          icon: OlIcons.search,
          semanticLabel: 'Cari',
          onHero: true,
          onPressed: () => context.push(Routes.search),
        ),
        const SizedBox(width: 4),
        OlIconButton(
          icon: OlIcons.bell,
          semanticLabel: 'Notifikasi',
          onHero: true,
          onPressed: () => context.push(Routes.notifications),
        ),
      ],
      below: SyncIndicator(
        status: ref.watch(syncStatusProvider),
        onHero: true,
        onTap: () => context.push(Routes.syncStatus),
      ),
    );

    final children = <Widget>[
      _Summary(schedule: schedule, filter: filter),
      _DayStrip(selected: day, today: dateOnly(now)),
      const FeedbackBannerHost(),
      ...switch (async) {
        AsyncData(:final value) => _content(value, filter, now),
        _ when async.hasError && schedule == null => [
          _ErrorState(error: async.error!, onRetry: _retry),
        ],
        _ when schedule != null => _content(schedule, filter, now),
        _ => [const SkeletonList(count: 3)],
      },
    ];

    return RefreshIndicator(
      color: context.ol.brand,
      onRefresh: () =>
          ref.read(therapistScheduleProvider(day).notifier).refresh(),
      child: OlPageBody(heroOverlap: true, header: header, children: children),
    );
  }

  void _retry() =>
      ref.invalidate(therapistScheduleProvider(ref.read(selectedDayProvider)));

  List<Widget> _content(DaySchedule d, ScheduleFilter filter, DateTime now) {
    final list = switch (filter) {
      ScheduleFilter.all => d.sessions,
      ScheduleFilter.homeVisit =>
        d.sessions.where((s) => s.isHomeVisit).toList(),
      ScheduleFilter.newPatient =>
        d.sessions.where((s) => s.isNewPatient).toList(),
    };
    final isToday = d.day == dateOnly(now);
    final next = isToday ? d.nextAfter(now) : null;
    return [
      if (d.stale) ...[
        const OlBanner(
          tone: OlBannerTone.warn,
          icon: OlIcons.offline,
          message: 'Kamu sedang offline. Data tersimpan di HP.',
        ),
        if (d.fetchedAt != null)
          Text(
            'Data terakhir diperbarui ${Fmt.time(d.fetchedAt!)}',
            style: context.olText.caption,
          ),
      ],
      if (list.isEmpty)
        OlCard(
          child: EmptyState(
            illustration: OlIllustration.emptySchedule,
            title: filter == ScheduleFilter.all
                ? 'Tidak ada sesi ${isToday ? 'hari ini' : 'di tanggal ini'}'
                : 'Tidak ada sesi yang cocok',
            message: filter == ScheduleFilter.all
                ? 'Belum ada sesi terjadwal untukmu.'
                : 'Ketuk ringkasan yang sama untuk menampilkan semua sesi.',
            actionLabel: filter == ScheduleFilter.all
                ? 'Lihat jadwal minggu ini'
                : 'Tampilkan semua',
            onAction: filter == ScheduleFilter.all
                ? () => context.push(Routes.terapisJadwalMinggu)
                : () =>
                      ref.read(scheduleFilterProvider.notifier).toggle(filter),
          ),
        )
      else
        for (final s in list)
          SessionCard(
            key: s.status == SessionStatus.running
                ? _runningKey
                : ValueKey(s.id),
            session: s,
            now: now,
            nextUp: s.id == next?.id,
            onTap: () => _open(s),
            onOpenRecord: () => context.push(Routes.terapisRekam(s.id)),
            onStart: isToday ? () => _start(d.day, s) : null,
            startBlockedReason: startBlockReason(d, s),
            onMore:
                s.isFinished ||
                    s.status == SessionStatus.running ||
                    s.status == SessionStatus.noShow ||
                    s.status == SessionStatus.cancelled
                ? null
                : () => _more(d.day, s),
          ),
    ];
  }

  static String _greeting(DateTime now, String name) {
    final h = now.hour;
    final part = h < 11
        ? 'Pagi'
        : (h < 15 ? 'Siang' : (h < 18 ? 'Sore' : 'Malam'));
    return '$part, $name';
  }
}

enum _Action { homeVisit, reschedule, noShow }

/// 3 ringkasan: sesi · home visit · pasien baru. Ketuk → filter (§5.1).
class _Summary extends ConsumerWidget {
  const _Summary({required this.schedule, required this.filter});

  final DaySchedule? schedule;
  final ScheduleFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = schedule;
    Widget tile(String label, int? value, ScheduleFilter f) => Expanded(
      child: _SummaryTile(
        label: label,
        value: value,
        selected: filter == f && f != ScheduleFilter.all,
        onTap: d == null
            ? null
            : () => ref.read(scheduleFilterProvider.notifier).toggle(f),
      ),
    );
    final isToday = d == null || d.day == dateOnly(ref.read(clockProvider)());
    return Row(
      children: [
        tile(
          isToday ? 'sesi hari ini' : 'sesi',
          d?.sessions.length,
          ScheduleFilter.all,
        ),
        const SizedBox(width: 10),
        tile('home visit', d?.homeVisits, ScheduleFilter.homeVisit),
        const SizedBox(width: 10),
        tile('pasien baru', d?.newPatients, ScheduleFilter.newPatient),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.selected,
    this.onTap,
  });

  final String label;
  final int? value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final radius = BorderRadius.circular(18);
    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      label: '${value ?? '–'} $label${selected ? ', filter aktif' : ''}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: OlMotion.of(context, OlMotion.fast),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          boxShadow: OlShadow.sh1,
          border: Border.all(
            color: selected ? c.brand : Colors.transparent,
            width: 2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  value == null
                      ? const Skeleton(width: 24, height: 26)
                      : Text(
                          '$value',
                          style: t.display.copyWith(fontSize: 26, height: 1.1),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 2,
                    style: t.caption.copyWith(
                      fontSize: 13,
                      color: selected ? c.brand : c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Strip 6 hari (kemarin s.d. 4 hari ke depan) + tombol jadwal minggu (TR-02).
class _DayStrip extends ConsumerWidget {
  const _DayStrip({required this.selected, required this.today});

  final DateTime selected;
  final DateTime today;

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ol;
    final t = context.olText;
    final days = [for (var i = -1; i <= 4; i++) today.add(Duration(days: i))];
    return Row(
      children: [
        for (final d in days) ...[
          Expanded(
            child: _DayPill(
              label: _days[d.weekday - 1],
              day: d.day,
              selected: d == selected,
              isToday: d == today,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(selectedDayProvider.notifier).select(d);
              },
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Semantics(
            container: true,
            button: true,
            label: 'Jadwal minggu',
            excludeSemantics: true,
            // Bayangan di wadah luar; Material transparan di dalam (tanpa kotak abu).
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: OlShadow.sh1,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(Routes.terapisJadwalMinggu),
                  child: Center(
                    child: OlIcon(OlIcons.calendar, color: t.body.color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.label,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final int day;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '$label $day${isToday ? ', hari ini' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: OlMotion.of(context, OlMotion.fast),
          curve: OlMotion.curve,
          height: 64,
          decoration: BoxDecoration(
            color: selected ? c.brandDeep : c.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0xCC0B3B5C),
                      offset: Offset(0, 12),
                      blurRadius: 20,
                      spreadRadius: -12,
                    ),
                  ]
                : OlShadow.sh1,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: t.caption.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFFA9D8F2) : c.muted,
                ),
              ),
              Text(
                '$day',
                style: t.heading.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : c.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ST-03: jadwal gagal dimuat (atau offline tanpa cache).
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final e = error is AppError
        ? error as AppError
        : const AppError(ErrorCode.unknown);
    final offline =
        e.type == ErrorCode.networkOffline ||
        e.type == ErrorCode.networkTimeout;
    return OlCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            OlIllustrationImage(
              offline ? OlIllustration.offline : OlIllustration.serverError,
              width: 200,
            ),
            const SizedBox(height: 20),
            Text(
              offline ? 'Kamu sedang offline' : 'Ada gangguan di server',
              style: t.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              offline
                  ? 'Jadwal belum pernah dimuat di HP ini. Sambungkan internet lalu coba lagi.'
                  : 'Jadwal belum bisa dimuat. Coba beberapa saat lagi — catatan sesi tetap bisa diisi offline.',
              style: t.body.copyWith(color: context.ol.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OlButton(label: 'Coba lagi', expand: false, onPressed: onRetry),
            if (e.refId != null) ...[
              const SizedBox(height: 10),
              Text(
                'Ref: ${e.refId}',
                style: t.mono.copyWith(fontSize: 12, color: context.ol.faint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RescheduleForm extends StatefulWidget {
  const _RescheduleForm({required this.onSubmit});
  final void Function(({String reason, String proposal}) result) onSubmit;

  @override
  State<_RescheduleForm> createState() => _RescheduleFormState();
}

class _RescheduleFormState extends State<_RescheduleForm> {
  final _reason = TextEditingController();
  final _proposal = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _proposal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OlTextField(
        label: 'Alasan',
        isRequired: true,
        controller: _reason,
        maxLines: 3,
        error: _error,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      const SizedBox(height: OlSpace.lg),
      OlTextField(
        label: 'Usulan jam (opsional)',
        hint: 'mis. besok 10.00',
        controller: _proposal,
      ),
      const SizedBox(height: OlSpace.xl),
      OlButton(
        label: 'Kirim permintaan',
        onPressed: () {
          if (_reason.text.trim().isEmpty) {
            setState(() => _error = 'Tulis alasannya, mis. "terapis sakit".');
            return;
          }
          widget.onSubmit((reason: _reason.text, proposal: _proposal.text));
        },
      ),
    ],
  );
}
