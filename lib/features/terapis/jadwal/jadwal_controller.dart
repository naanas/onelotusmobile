import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/auth/auth_controller.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../../ui/feedback/app_error.dart';

/// Jadwal satu hari untuk terapis yang login (TR-01).
class DaySchedule {
  const DaySchedule({
    required this.day,
    required this.sessions,
    this.stale = false,
    this.fetchedAt,
  });

  final DateTime day;
  final List<Session> sessions;

  /// Dari cache HP karena offline (ST-04).
  final bool stale;
  final DateTime? fetchedAt;

  Session? get running =>
      sessions.where((s) => s.status == SessionStatus.running).firstOrNull;
  int get homeVisits => sessions.where((s) => s.isHomeVisit).length;
  int get newPatients => sessions.where((s) => s.isNewPatient).length;

  /// Sesi berikutnya yang belum dimulai (untuk "berikutnya dalam n mnt").
  Session? nextAfter(DateTime now) => sessions
      .where(
        (s) =>
            (s.status == SessionStatus.scheduled ||
                s.status == SessionStatus.arrived) &&
            s.startAt.isAfter(now),
      )
      .firstOrNull;

  DaySchedule replace(Session updated) => DaySchedule(
    day: day,
    sessions: [for (final s in sessions) s.id == updated.id ? updated : s],
    stale: stale,
    fetchedAt: fetchedAt,
  );
}

/// Filter dari 3 ringkasan di atas (§5.1: ketuk → filter daftar).
enum ScheduleFilter { all, homeVisit, newPatient }

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

final selectedDayProvider = NotifierProvider<SelectedDay, DateTime>(
  SelectedDay.new,
);

class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(ref.read(clockProvider)());

  void select(DateTime day) => state = dateOnly(day);
}

final scheduleFilterProvider =
    NotifierProvider<ScheduleFilterNotifier, ScheduleFilter>(
      ScheduleFilterNotifier.new,
    );

class ScheduleFilterNotifier extends Notifier<ScheduleFilter> {
  @override
  ScheduleFilter build() {
    ref.watch(selectedDayProvider); // ganti hari → filter direset
    return ScheduleFilter.all;
  }

  /// Ketuk ringkasan yang sama lagi = hapus filter.
  void toggle(ScheduleFilter f) => state = state == f ? ScheduleFilter.all : f;
}

final therapistScheduleProvider =
    AsyncNotifierProvider.family<
      TherapistScheduleNotifier,
      DaySchedule,
      DateTime
    >(
      TherapistScheduleNotifier.new,
      // Tanpa coba ulang otomatis: layar menampilkan error + "Coba lagi" (ST-03),
      // pengguna yang memutuskan kapan mencoba lagi.
      retry: (_, _) => null,
    );

/// Alasan "Mulai sesi" tidak tersedia, atau null bila boleh.
String? startBlockReason(DaySchedule schedule, Session s) {
  if (s.status != SessionStatus.arrived) {
    // TODO(TR-09): home visit boleh dimulai dari status Dijadwalkan setelah check-in.
    return 'Mulai sesi setelah pasien ditandai hadir.';
  }
  final running = schedule.running;
  if (running != null && running.id != s.id) {
    return 'Selesaikan sesi ${running.patientName} dulu. Hanya 1 sesi berjalan.';
  }
  return null;
}

class TherapistScheduleNotifier extends AsyncNotifier<DaySchedule> {
  TherapistScheduleNotifier(this.day);

  final DateTime day;

  @override
  Future<DaySchedule> build() async {
    final auth = ref.watch(authProvider);
    final branch = auth.activeBranch;
    final user = auth.user;
    if (branch == null || user == null) {
      return DaySchedule(day: day, sessions: const []);
    }
    final f = await ref
        .read(scheduleRepositoryProvider)
        .sessionsForDay(branchId: branch.id, day: day, therapistId: user.id);
    return DaySchedule(
      day: day,
      sessions: f.data,
      stale: f.stale,
      fetchedAt: f.fetchedAt,
    );
  }

  /// Tarik untuk refresh. Data lama tetap tampil selama memuat.
  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<Session> _update(
    Session s,
    SessionStatus status, {
    String? reason,
  }) async {
    final updated = await ref
        .read(scheduleRepositoryProvider)
        .updateStatus(s, status, reason: reason);
    final current = state.value;
    if (current != null) state = AsyncData(current.replace(updated));
    return updated;
  }

  /// TR-01: Mulai sesi (Hadir → Berjalan). Melempar [AppError] bila aturan tidak terpenuhi.
  Future<Session> start(Session s) {
    final current = state.value;
    final blocked = current == null ? null : startBlockReason(current, s);
    if (blocked != null) throw StateError(blocked);
    return _update(s, SessionStatus.running);
  }

  /// Tidak datang — alasan wajib (TR-01).
  Future<Session> markNoShow(Session s, String reason) {
    if (reason.trim().isEmpty) throw const AppError(ErrorCode.validation);
    return _update(s, SessionStatus.noShow, reason: reason.trim());
  }

  Future<void> requestReschedule(
    Session s, {
    required String reason,
    String? proposal,
  }) => ref
      .read(scheduleRepositoryProvider)
      .requestReschedule(
        s,
        reason: reason.trim(),
        proposal: (proposal?.trim().isEmpty ?? true) ? null : proposal!.trim(),
      );
}

/// Sesi berjalan hari ini — tujuan FAB terapis (§3).
final runningSessionProvider = Provider<Session?>((ref) {
  final today = dateOnly(ref.watch(clockProvider)());
  return ref.watch(therapistScheduleProvider(today)).value?.running;
});
