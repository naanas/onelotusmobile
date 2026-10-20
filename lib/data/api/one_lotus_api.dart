import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/feedback/app_error.dart';
import '../auth/auth_controller.dart';
import '../models/json.dart';
import '../models/models.dart';
import '../providers.dart';
import '../remote/http_remote.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';
import 'v1.dart';

/// Endpoint staf One Lotus API v1 yang dipanggil langsung dari layar (online). Operasi yang harus aman
/// offline (status sesi oleh terapis, rekam sesi) tetap lewat repository + outbox.
/// Kontrak: `backend/docs/openapi.yaml`; terjemahan model di [V1].
class OneLotusApi {
  OneLotusApi(this.api, {StaffUser? Function()? me}) : _me = me ?? (() => null);

  final ApiClient api;
  final StaffUser? Function() _me;
  late final _remote = HttpRemote(api);

  static const _notImplemented = AppError(ErrorCode.unknown, apiCode: 'not_implemented');

  static String _key() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  // ── Jadwal & sesi ──────────────────────────────────────────────────────

  Future<List<Session>> sessions({
    required String branchId,
    required DateTime from,
    required DateTime to,
    String? therapistId,
  }) => _remote.sessions(branchId: branchId, from: from, to: to, therapistId: therapistId);

  Future<Session> session(String id) => api.get('/v1/sessions/$id', (d) => V1.session(asMap(d)));

  /// Nama ruang → id (layar memakai nama ruang).
  Future<String?> _roomId(String branchId, String? room) async {
    if (room == null || room.isEmpty) return null;
    final rooms = await this.rooms(branchId);
    return rooms.where((r) => r.name == room).firstOrNull?.id;
  }

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
  }) async => api.post(
    '/v1/sessions',
    {
      'patient_id': patientId,
      'service_id': serviceId,
      'therapist_id': therapistId,
      'any_therapist': therapistId == null,
      'room_id': await _roomId(branchId, room),
      'location_type': homeVisit == null ? 'clinic' : 'home_visit',
      if (homeVisit != null)
        'address': {
          'text': homeVisit.address,
          'landmark': homeVisit.landmark,
          'lat': homeVisit.lat,
          'lng': homeVisit.lng,
        },
      'start': formatDate(startAt ?? DateTime.now()),
      'note': note,
      'walk_in': walkIn,
    },
    (d) => V1.session(asMap(d)),
    headers: {'Idempotency-Key': _key()},
  );

  /// Ubah jadwal (KS-01 ganti terapis/ruang, KS-06 ubah). `room: ''` = hapus ruang.
  /// Layanan tidak bisa diganti lewat API v1 (batalkan & buat ulang).
  Future<Session> updateSession(
    String id, {
    DateTime? startAt,
    String? therapistId,
    String? serviceId,
    String? room,
    String? note,
    String? reason,
  }) async {
    final body = <String, dynamic>{
      if (startAt != null) 'start': formatDate(startAt),
      'therapist_id': ?therapistId,
      'note': [?note, ?reason].join(' · '),
    };
    if (room != null) {
      final s = await session(id);
      body['room_id'] = await _roomId(s.branchId, room);
    }
    return api.patch('/v1/sessions/$id', body, (d) => V1.session(asMap(d)));
  }

  /// Ubah status langsung (online) — layar front desk/owner. Terapis memakai outbox.
  Future<Session> setStatus(String id, SessionStatus status, {String? reason}) {
    final action = V1.transitionFor(status);
    if (action == null) throw const AppError(ErrorCode.validation);
    return api.post(
      '/v1/sessions/$id/transitions',
      {'action': action, 'reason': reason},
      (d) => V1.session(asMap(d)),
      headers: {'Idempotency-Key': _key()},
    );
  }

  /// Check-in home visit (TR-09): jarak & akurasi diperiksa server; di luar radius butuh [manualReason].
  Future<void> homeVisitCheckIn(String sessionId, {required double lat, required double lng, required double accuracy, String? manualReason}) =>
      api.post('/v1/sessions/$sessionId/home-visit/check-in', {
        'lat': lat,
        'lng': lng,
        'accuracy_m': accuracy,
        'manual_reason': manualReason,
      }, (_) {}, headers: {'Idempotency-Key': _key()});

  Future<void> homeVisitCheckOut(String sessionId) =>
      api.post('/v1/sessions/$sessionId/home-visit/check-out', null, (_) {});

  /// Batal di lokasi (pasien tidak ada / menolak) — sesi dibatalkan, kasir diberi tahu.
  Future<void> homeVisitCancel(String sessionId, String reason) =>
      api.post('/v1/sessions/$sessionId/home-visit/cancel', {'reason': reason}, (_) {});

  /// Pindah sesi massal (KS-08). Item tanpa terapis & jam tetap "Perlu tindakan" (tidak dikirim).
  Future<List<BulkMoveResult>> bulkMove(
    List<({String sessionId, String? therapistId, DateTime? startAt})> moves, {
    String? reason,
  }) async {
    final send = [for (final m in moves) if (m.therapistId != null || m.startAt != null) m];
    final out = [
      for (final m in moves)
        if (m.therapistId == null && m.startAt == null)
          BulkMoveResult(sessionId: m.sessionId, status: 'needs_action'),
    ];
    if (send.isEmpty) return out;
    try {
      final sessions = await api.post('/v1/sessions/bulk-reassign', {
        'items': [
          for (final m in send)
            {
              'session_id': m.sessionId,
              'therapist_id': ?m.therapistId,
              if (m.startAt != null) 'start': formatDate(m.startAt),
            },
        ],
      }, (d) => parseList(d, V1.session));
      return [
        ...out,
        for (final s in sessions) BulkMoveResult(sessionId: s.id, status: 'moved', session: s),
      ];
    } on AppError catch (e) {
      // Semua atau tidak sama sekali: tandai sesi yang gagal.
      final failed = e.details['session_id']?.toString();
      return [
        ...out,
        for (final m in send)
          BulkMoveResult(
            sessionId: m.sessionId,
            status: 'failed',
            errors: m.sessionId == failed || failed == null
                ? {'session': [e.apiMessage ?? e.message]}
                : const {},
          ),
      ];
    }
  }

  Future<List<Slot>> slots({
    required String branchId,
    required DateTime date,
    required String serviceId,
    String? therapistId,
    String? room,
    String? excludeSessionId,
    int step = 60,
  }) async {
    final all = await api.get(
      '/v1/slots',
      (d) => parseList(d, V1.slot),
      query: {
        'branch_id': branchId,
        'date': formatDay(date),
        'service_id': serviceId,
        'therapist_id': therapistId,
      },
    );
    // Server melangkah 15 menit; layar meminta langkah [step].
    return [for (final s in all) if ((s.startAt.hour * 60 + s.startAt.minute) % step == 0) s];
  }

  /// Daftar permintaan pindah dari terapis: API v1 menyampaikannya lewat notifikasi kasir
  /// (`session.changed`), tidak ada endpoint daftar.
  Future<List<RescheduleRequest>> rescheduleRequests(String branchId, {bool open = true}) async =>
      const [];

  Future<void> handleRescheduleRequest(String id, String resolution) async {}

  /// Tagihan sesi; null bila belum ada (modul tagihan = fase 2).
  Future<Invoice?> invoice(String sessionId) => _remote.invoiceForSession(sessionId);

  // ── Cabang, ruang, terapis, layanan ───────────────────────────────────

  Future<Map<String, dynamic>> _branchRaw(String id) async {
    final list = await api.get('/v1/branches', (d) => parseList(d, (m) => m));
    final b = list.where((m) => m['id'].toString() == id).firstOrNull;
    if (b == null) throw const AppError(ErrorCode.notFound);
    return b;
  }

  Future<BranchDetail> branch(String id) async => V1.branch(await _branchRaw(id));

  Future<BranchDetail> updateBranch(
    String id, {
    required String name,
    required String address,
    required Map<String, List<String>> openingHours,
    String? waNumber,
  }) async {
    final cur = await _branchRaw(id);
    return api.patch('/v1/branches/$id', {
      ...cur,
      'name': name,
      'address': address,
      'opening_hours': V1.openingHours(openingHours),
      'phone_wa': waNumber,
    }, (d) => V1.branch(asMap(d)));
  }

  Future<List<Room>> rooms(String branchId) async => (await branch(branchId)).rooms;

  /// Ruang dikelola lewat data cabang (OW-17) — belum ada endpoint ruang terpisah di API v1.
  Future<Room> saveRoom(
    String branchId, {
    String? roomId,
    required String name,
    int capacity = 1,
    bool isActive = true,
  }) async => throw _notImplemented;

  /// Terapis aktif cabang aktif (`GET /v1/staff`, kasir mendapat terapis saja).
  Future<List<Therapist>> therapists(String branchId, {DateTime? date}) async {
    final list = await api.get('/v1/staff', (d) => parseList(d, (m) => m));
    return [
      for (final m in list)
        if (m['status'] == 'active' &&
            (m['roles'] as List? ?? const []).any(
              (r) => (r as Map)['role'] == 'therapist' && r['branch_id'].toString() == branchId,
            ))
          Therapist(id: m['id'].toString(), name: m['name'] as String),
    ];
  }

  Future<List<Service>> services(String branchId) => _remote.services(branchId: branchId);

  // ── Pasien ─────────────────────────────────────────────────────────────

  final _patientCursors = <String, String?>{};

  Future<PageResult<Patient>> patients({
    String query = '',
    int page = 1,
    bool mine = false,
    PatientFilter filter = const PatientFilter(),
  }) async {
    final f = filter.hasPackage
        ? 'has_package'
        : filter.away
        ? 'inactive_30d'
        : filter.unpaid
        ? 'unpaid'
        : null;
    final key = '$query|$f|${filter.archived}';
    if (page == 1) _patientCursors.remove(key);
    if (page > 1 && _patientCursors[key] == null) {
      return PageResult(items: const [], page: page, lastPage: page, total: 0);
    }
    final res = await api.getPage('/v1/patients', V1.patientItem, query: {
      'q': query,
      'filter': f,
      if (filter.archived) 'archived': 'true',
      'limit': 20,
      'cursor': page > 1 ? _patientCursors[key] : null,
    });
    _patientCursors[key] = res.hasMore ? res.nextCursor : null;
    return PageResult(
      items: res.items,
      page: page,
      lastPage: res.hasMore ? page + 1 : page,
      total: res.items.length,
    );
  }

  Future<Patient> patient(String id) => _remote.patient(id);

  Future<PageResult<SessionRecord>> patientRecords(String id, {int page = 1}) async {
    final p = await _remote.recordHistory(id, page: page);
    return PageResult(items: p.items, page: page, lastPage: p.hasMore ? page + 1 : page, total: p.items.length);
  }

  Future<List<LegacyRecord>> legacyRecords(String id) => _remote.legacyRecords(id);

  Future<Patient> updatePatient(
    String id,
    PatientDraft draft, {
    bool confirmNotDuplicate = false,
  }) async {
    try {
      return await api.patch(
        '/v1/patients/$id',
        V1.patientInput(draft, force: confirmNotDuplicate),
        (d) => V1.patient(asMap(d)),
      );
    } on DuplicatePatientError catch (e) {
      throw DuplicatePatientError(
        candidates: [for (final c in e.candidates) V1.duplicateCandidate(c)],
        refId: e.refId,
      );
    }
  }

  Future<void> archivePatient(String id) =>
      api.post('/v1/patients/$id/archive', {'reason': null}, (_) {});

  Future<void> restorePatient(String id) => api.post('/v1/patients/$id/restore', null, (_) {});

  // ── Ketersediaan & cuti ────────────────────────────────────────────────

  /// Senin minggu ini.
  static DateTime _monday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
  }

  /// Minggu-minggu jadwal terapis (TR-02) — sumber blok & cuti (API v1 tidak punya daftar terpisah).
  Future<List<Map<String, dynamic>>> _weeks(String therapistId, int count) async {
    final start = _monday();
    final weeks = await Future.wait([
      for (var i = 0; i < count; i++)
        api.get(
          '/v1/therapists/$therapistId/week',
          (d) => parseList(asMap(d)['days'], (m) => m),
          query: {'week_start': formatDay(start.add(Duration(days: 7 * i)))},
        ),
    ]);
    return weeks.expand((w) => w).toList();
  }

  Future<List<TherapistBlock>> blocks({String? therapistId}) async {
    final id = therapistId ?? _me()?.id;
    if (id == null) return const [];
    final seen = <String, TherapistBlock>{};
    for (final d in await _weeks(id, 4)) {
      for (final b in (d['blocks'] as List? ?? const [])) {
        final blk = V1.block(asMap(b));
        seen[blk.id] = blk;
      }
    }
    return seen.values.toList();
  }

  Future<TherapistBlock> createBlock({
    required String kind,
    DateTime? startsAt,
    DateTime? endsAt,
    int? weekday,
    String? startTime,
    String? endTime,
    String? note,
  }) => api.post(
    '/v1/availability-blocks',
    V1.blockInput(
      kind: kind,
      startsAt: startsAt,
      endsAt: endsAt,
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
      note: note,
    ),
    (d) => V1.block(asMap(d)),
  );

  Future<void> deleteBlock(String id) => api.delete('/v1/availability-blocks/$id', (_) {});

  /// [mine] = cuti terapis login (dari jadwal 8 minggu ke depan); selain itu antrean persetujuan owner.
  Future<List<LeaveRequest>> leaves({bool mine = false, String? status}) async {
    if (mine) {
      final me = _me();
      if (me == null) return const [];
      final seen = <String, LeaveRequest>{};
      for (final d in await _weeks(me.id, 8)) {
        if (d['leave'] is Map) {
          final l = V1.leave(asMap(d['leave']), therapistId: me.id, therapistName: me.name);
          seen[l.id] = l;
        }
      }
      return [for (final l in seen.values) if (status == null || l.status.api == status) l];
    }
    return api.get(
      '/v1/approvals',
      (d) => parseList(d, V1.leaveApproval),
      query: {'type': 'leave', 'status': status},
    );
  }

  Future<LeaveRequest> createLeave({
    required DateTime startsAt,
    required DateTime endsAt,
    required bool allDay,
    required String reason,
    String? note,
  }) => api.post('/v1/leave-requests', {
    'starts_at': formatDate(allDay ? DateTime(startsAt.year, startsAt.month, startsAt.day) : startsAt),
    'ends_at': formatDate(allDay ? DateTime(endsAt.year, endsAt.month, endsAt.day) : endsAt),
    'all_day': allDay,
    'reason_code': reason,
    'note': note,
  }, (d) => V1.leave(asMap(d), therapistId: _me()?.id ?? '', therapistName: _me()?.name ?? ''));

  Future<void> cancelLeave(String id) => api.post('/v1/leave-requests/$id/cancel', null, (_) {});

  /// Owner menyetujui / menolak cuti ([id] = id approval) → sesi terdampak untuk dipindah (KS-08).
  Future<List<Session>> decideLeave(String id, {required bool approve, String? reason}) async {
    final res = await api.post('/v1/approvals/$id/decide', {
      'decision': approve ? 'approve' : 'reject',
      'reason': reason,
    }, asMap);
    if (!approve) return const [];
    final leave = V1.leaveApproval(asMap(res['approval']));
    final branchId = _me()?.branches.firstOrNull?.id;
    if (branchId == null || leave.therapistId.isEmpty) return const [];
    final list = await sessions(
      branchId: branchId,
      from: leave.startsAt,
      to: leave.endsAt.add(const Duration(days: 1)),
      therapistId: leave.therapistId,
    );
    return [for (final s in list) if (s.needsAction) s];
  }

  Future<List<PasswordResetRequest>> passwordResets({bool open = true}) => api.get(
    '/v1/approvals',
    (d) => parseList(d, V1.passwordReset),
    query: {'type': 'password_reset', if (open) 'status': 'pending'},
  );

  /// Setuju → password sementara (ditampilkan sekali); tolak → null.
  Future<String?> decidePasswordReset(String id, {required bool approve}) => api.post(
    '/v1/approvals/$id/decide',
    {'decision': approve ? 'approve' : 'reject', if (!approve) 'reason': 'Ditolak owner'},
    (d) => asMap(d)['temporary_password'] as String?,
  );

  // ── Staf (OW-08) ───────────────────────────────────────────────────────

  Future<List<StaffMember>> staff() => api.get('/v1/staff', (d) => parseList(d, V1.staff));

  /// Buat staf → (anggota, password sementara).
  Future<(StaffMember, String)> createStaff({
    required String name,
    required String username,
    required List<Role> roles,
    required List<String> branchIds,
    String? phone,
  }) => api.post(
    '/v1/staff',
    V1.staffInput(name: name, username: username, roles: roles, branchIds: branchIds, phone: phone),
    (d) {
      final m = asMap(d);
      return (V1.staff(asMap(m['staff'])), m['temporary_password'] as String);
    },
  );

  Future<StaffMember> updateStaff(
    String id, {
    required String name,
    required List<Role> roles,
    required List<String> branchIds,
    String? phone,
  }) async {
    final cur = (await staff()).where((m) => m.user.id == id).firstOrNull;
    return api.patch(
      '/v1/staff/$id',
      V1.staffInput(
        name: name,
        username: cur?.user.username ?? '',
        roles: roles,
        branchIds: branchIds,
        phone: phone,
      ),
      (d) => V1.staff(asMap(d)),
    );
  }

  Future<void> setStaffActive(String id, bool active) =>
      api.post('/v1/staff/$id/${active ? 'activate' : 'deactivate'}', null, (_) {});

  Future<String> resetStaffPassword(String id) => api.post(
    '/v1/staff/$id/reset-password',
    null,
    (d) => asMap(d)['temporary_password'] as String,
  );

  Future<void> revokeStaffTokens(String id) => api.post('/v1/staff/$id/sign-out-all', null, (_) {});
}

final oneLotusApiProvider = Provider<OneLotusApi>(
  (ref) => OneLotusApi(ref.watch(apiClientProvider), me: () => ref.read(authProvider).user),
);
