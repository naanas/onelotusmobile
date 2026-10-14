import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/feedback/app_error.dart';
import '../models/json.dart';
import '../models/models.dart';
import '../providers.dart';
import 'api_client.dart';

/// Endpoint staf One Lotus API yang dipanggil langsung dari layar (online). Operasi yang harus aman
/// offline (status sesi, rekam sesi) tetap lewat repository + outbox. Kontrak: docs/api-kontrak.md.
class OneLotusApi {
  OneLotusApi(this.api);

  final ApiClient api;

  static PageResult<T> _page<T>(
    dynamic body,
    T Function(Map<String, dynamic>) f,
  ) {
    final m = asMap(body);
    final meta = asMap(m['meta'] ?? const <String, dynamic>{});
    return PageResult(
      items: parseList(m['data'], f),
      page: parseInt(meta['current_page']) ?? 1,
      lastPage: parseInt(meta['last_page']) ?? 1,
      total: parseInt(meta['total']) ?? 0,
    );
  }

  // ── Jadwal & sesi ──────────────────────────────────────────────────────

  Future<List<Session>> sessions({
    required String branchId,
    required DateTime from,
    required DateTime to,
    String? therapistId,
  }) => api.get(
    '/v1/sessions',
    (d) => parseList(d, Session.fromJson),
    query: {
      'branch_id': branchId,
      'from': formatDate(from),
      'to': formatDate(to),
      'therapist_id': ?therapistId,
    },
  );

  Future<Session> session(String id) =>
      api.get('/v1/sessions/$id', (d) => Session.fromJson(asMap(d)));

  /// Buat jadwal (KS-06) atau walk-in (`walkIn` → langsung Hadir).
  Future<Session> createSession({
    required String patientId,
    required String serviceId,
    required String branchId,
    String? therapistId,
    DateTime? startAt,
    String? room,
    HomeVisit? homeVisit,
    String? note,
    bool walkIn = false,
  }) => api.post('/v1/sessions', {
    'patient_id': patientId,
    'service_id': serviceId,
    'branch_id': branchId,
    'therapist_id': ?therapistId,
    if (startAt != null) 'start_at': formatDate(startAt),
    'room': ?room,
    if (homeVisit != null) 'home_visit': homeVisit.toJson(),
    'note': ?note,
    'walk_in': walkIn,
  }, (d) => Session.fromJson(asMap(d)));

  /// Ubah sebagian jadwal (KS-01 ganti terapis/ruang, KS-06 ubah). `room: ''` = hapus ruang.
  Future<Session> updateSession(
    String id, {
    DateTime? startAt,
    String? therapistId,
    String? serviceId,
    String? room,
    String? note,
    String? reason,
  }) => api.patch('/v1/sessions/$id', {
    if (startAt != null) 'start_at': formatDate(startAt),
    'therapist_id': ?therapistId,
    'service_id': ?serviceId,
    'room': ?room,
    'note': ?note,
    'reason': ?reason,
  }, (d) => Session.fromJson(asMap(d)));

  /// Ubah status langsung (online) — untuk layar front desk/owner. Terapis memakai outbox.
  Future<Session> setStatus(
    String id,
    SessionStatus status, {
    String? reason,
  }) => api.patch('/v1/sessions/$id/status', {
    'status': status.api,
    'at': formatDate(DateTime.now()),
    'reason': ?reason,
  }, (d) => Session.fromJson(asMap(d)));

  /// Pindah sesi massal (KS-08). Item tanpa terapis & jam → "Perlu tindakan".
  Future<List<BulkMoveResult>> bulkMove(
    List<({String sessionId, String? therapistId, DateTime? startAt})> moves, {
    String? reason,
  }) => api.post('/v1/sessions/bulk-move', {
    'reason': ?reason,
    'moves': [
      for (final m in moves)
        {
          'session_id': m.sessionId,
          'therapist_id': ?m.therapistId,
          if (m.startAt != null) 'start_at': formatDate(m.startAt),
        },
    ],
  }, (d) => parseList(d, BulkMoveResult.fromJson));

  Future<List<Slot>> slots({
    required String branchId,
    required DateTime date,
    required String serviceId,
    String? therapistId,
    String? room,
    String? excludeSessionId,
    int step = 60,
  }) => api.get(
    '/v1/slots',
    (d) => parseList(d, Slot.fromJson),
    query: {
      'branch_id': branchId,
      'date': formatDay(date),
      'service_id': serviceId,
      'therapist_id': ?therapistId,
      'room': ?room,
      'exclude_session_id': ?excludeSessionId,
      'step': step,
    },
  );

  Future<List<RescheduleRequest>> rescheduleRequests(
    String branchId, {
    bool open = true,
  }) => api.get(
    '/v1/reschedule-requests',
    (d) => parseList(d, RescheduleRequest.fromJson),
    query: {'branch_id': branchId, 'open': '$open'},
  );

  Future<void> handleRescheduleRequest(String id, String resolution) =>
      api.post('/v1/reschedule-requests/$id/handle', {
        'resolution': resolution,
      }, (_) {});

  /// Tagihan sesi; null bila belum ada.
  Future<Invoice?> invoice(String sessionId) async {
    try {
      return await api.get(
        '/v1/sessions/$sessionId/invoice',
        (d) => Invoice.fromJson(asMap(d)),
      );
    } on AppError catch (e) {
      if (e.type == ErrorCode.notFound) return null;
      rethrow;
    }
  }

  // ── Cabang, ruang, terapis, layanan ───────────────────────────────────

  Future<BranchDetail> branch(String id) =>
      api.get('/v1/branches/$id', (d) => BranchDetail.fromJson(asMap(d)));

  Future<BranchDetail> updateBranch(
    String id, {
    required String name,
    required String address,
    required Map<String, List<String>> openingHours,
    String? waNumber,
  }) => api.put('/v1/branches/$id', {
    'name': name,
    'address': address,
    'opening_hours': openingHours,
    'wa_number': waNumber,
  }, (d) => BranchDetail.fromJson(asMap(d)));

  Future<List<Room>> rooms(String branchId) => api.get(
    '/v1/branches/$branchId/rooms',
    (d) => parseList(d, Room.fromJson),
  );

  Future<Room> saveRoom(
    String branchId, {
    String? roomId,
    required String name,
    int capacity = 1,
    bool isActive = true,
  }) {
    final body = {'name': name, 'capacity': capacity, 'is_active': isActive};
    return roomId == null
        ? api.post(
            '/v1/branches/$branchId/rooms',
            body,
            (d) => Room.fromJson(asMap(d)),
          )
        : api.put(
            '/v1/branches/$branchId/rooms/$roomId',
            body,
            (d) => Room.fromJson(asMap(d)),
          );
  }

  Future<List<Therapist>> therapists(String branchId, {DateTime? date}) =>
      api.get(
        '/v1/branches/$branchId/therapists',
        (d) => parseList(d, Therapist.fromJson),
        query: {if (date != null) 'date': formatDay(date)},
      );

  Future<List<Service>> services(String branchId) => api.get(
    '/v1/services',
    (d) => parseList(d, Service.fromJson),
    query: {'branch_id': branchId},
  );

  // ── Pasien ─────────────────────────────────────────────────────────────

  Future<PageResult<Patient>> patients({
    String query = '',
    int page = 1,
    bool mine = false,
    PatientFilter filter = const PatientFilter(),
  }) => api.getBody(
    '/v1/patients',
    (b) => _page(b, Patient.fromJson),
    query: {
      'q': query,
      'page': page,
      'per_page': 20,
      if (mine) 'scope': 'mine',
      ...filter.toQuery(),
    },
  );

  Future<Patient> patient(String id) =>
      api.get('/v1/patients/$id', (d) => Patient.fromJson(asMap(d)));

  Future<PageResult<SessionRecord>> patientRecords(String id, {int page = 1}) =>
      api.getBody(
        '/v1/patients/$id/records',
        (b) => _page(b, SessionRecord.fromJson),
        query: {'page': page, 'per_page': 20},
      );

  Future<List<LegacyRecord>> legacyRecords(String id) => api.get(
    '/v1/patients/$id/legacy-records',
    (d) => parseList(d, LegacyRecord.fromJson),
  );

  Future<Patient> updatePatient(
    String id,
    PatientDraft draft, {
    bool confirmNotDuplicate = false,
  }) => api.put('/v1/patients/$id', {
    ...draft.toJson(),
    'confirm_not_duplicate': confirmNotDuplicate,
  }, (d) => Patient.fromJson(asMap(d)));

  Future<void> archivePatient(String id) =>
      api.post('/v1/patients/$id/archive', null, (_) {});

  Future<void> restorePatient(String id) =>
      api.post('/v1/patients/$id/restore', null, (_) {});

  // ── Ketersediaan & cuti ────────────────────────────────────────────────

  Future<List<TherapistBlock>> blocks({String? therapistId}) => api.get(
    '/v1/therapist-blocks',
    (d) => parseList(d, TherapistBlock.fromJson),
    query: {'therapist_id': ?therapistId},
  );

  Future<TherapistBlock> createBlock({
    required String kind,
    DateTime? startsAt,
    DateTime? endsAt,
    int? weekday,
    String? startTime,
    String? endTime,
    String? note,
  }) => api.post('/v1/therapist-blocks', {
    'kind': kind,
    if (startsAt != null) 'starts_at': formatDate(startsAt),
    if (endsAt != null) 'ends_at': formatDate(endsAt),
    'weekday': ?weekday,
    'start_time': ?startTime,
    'end_time': ?endTime,
    'note': ?note,
  }, (d) => TherapistBlock.fromJson(asMap(d)));

  Future<void> deleteBlock(String id) =>
      api.delete('/v1/therapist-blocks/$id', (_) {});

  Future<List<LeaveRequest>> leaves({bool mine = false, String? status}) =>
      api.get(
        '/v1/leave-requests',
        (d) => parseList(d, LeaveRequest.fromJson),
        query: {if (mine) 'scope': 'mine', 'status': ?status},
      );

  Future<LeaveRequest> createLeave({
    required DateTime startsAt,
    required DateTime endsAt,
    required bool allDay,
    required String reason,
    String? note,
  }) => api.post('/v1/leave-requests', {
    'starts_at': allDay ? formatDay(startsAt) : formatDate(startsAt),
    'ends_at': allDay ? formatDay(endsAt) : formatDate(endsAt),
    'all_day': allDay,
    'reason': reason,
    'note': ?note,
  }, (d) => LeaveRequest.fromJson(asMap(d)));

  Future<void> cancelLeave(String id) =>
      api.post('/v1/leave-requests/$id/cancel', null, (_) {});

  /// Owner menyetujui / menolak cuti → sesi terdampak untuk dipindah (KS-08).
  Future<List<Session>> decideLeave(
    String id, {
    required bool approve,
    String? reason,
  }) => api.post(
    '/v1/leave-requests/$id/decision',
    {'approve': approve, 'reason': ?reason},
    (d) =>
        parseList(asMap(d)['affected_sessions'] ?? const [], Session.fromJson),
  );

  Future<List<PasswordResetRequest>> passwordResets({bool open = true}) =>
      api.get(
        '/v1/password-reset-requests',
        (d) => parseList(d, PasswordResetRequest.fromJson),
        query: {'open': '$open'},
      );

  /// Setuju → password sementara (ditampilkan sekali); tolak → null.
  Future<String?> decidePasswordReset(String id, {required bool approve}) =>
      api.post(
        '/v1/password-reset-requests/$id/decision',
        {'approve': approve},
        (d) => d is Map ? d['temporary_password'] as String? : null,
      );

  // ── Staf (OW-08) ───────────────────────────────────────────────────────

  Future<List<StaffMember>> staff() =>
      api.get('/v1/staff', (d) => parseList(d, StaffMember.fromJson));

  /// Buat staf → (anggota, password sementara).
  Future<(StaffMember, String)> createStaff({
    required String name,
    required String username,
    required List<Role> roles,
    required List<String> branchIds,
    String? phone,
  }) => api.post(
    '/v1/staff',
    {
      'name': name,
      'username': username,
      'roles': [for (final r in roles) r.id],
      'branch_ids': branchIds,
      'phone': ?phone,
    },
    (d) {
      final m = asMap(d);
      return (
        StaffMember.fromJson(asMap(m['user'])),
        m['temporary_password'] as String,
      );
    },
  );

  Future<StaffMember> updateStaff(
    String id, {
    required String name,
    required List<Role> roles,
    required List<String> branchIds,
    String? phone,
  }) => api.put('/v1/staff/$id', {
    'name': name,
    'roles': [for (final r in roles) r.id],
    'branch_ids': branchIds,
    'phone': ?phone,
  }, (d) => StaffMember.fromJson(asMap(d)));

  Future<void> setStaffActive(String id, bool active) => api.post(
    '/v1/staff/$id/${active ? 'activate' : 'deactivate'}',
    null,
    (_) {},
  );

  Future<String> resetStaffPassword(String id) => api.post(
    '/v1/staff/$id/reset-password',
    null,
    (d) => asMap(d)['temporary_password'] as String,
  );

  Future<void> revokeStaffTokens(String id) =>
      api.post('/v1/staff/$id/revoke-tokens', null, (_) {});
}

final oneLotusApiProvider = Provider<OneLotusApi>(
  (ref) => OneLotusApi(ref.watch(apiClientProvider)),
);
