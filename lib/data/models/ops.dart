import 'json.dart';
import 'patient.dart';
import 'session.dart';
import 'staff_user.dart';

/// Model operasional front desk & owner (KS-01, KS-06, KS-08, TR-02, TR-03, OW-06, OW-08, OW-17).
/// Bentuk JSON = backend `internal/mobile` (docs/api-kontrak.md).

class Therapist {
  const Therapist({
    required this.id,
    required this.name,
    this.available,
    this.unavailableReason,
  });

  final String id;
  final String name;

  /// Diisi bila daftar diminta untuk tanggal tertentu (`false` = cuti seharian).
  final bool? available;
  final String? unavailableReason;

  factory Therapist.fromJson(Map<String, dynamic> j) => Therapist(
    id: j['id'].toString(),
    name: j['name'] as String,
    available: j['available'] as bool?,
    unavailableReason: j['unavailable_reason'] as String?,
  );
}

class Room {
  const Room({required this.id, required this.name, required this.capacity});

  final String id;
  final String name;
  final int capacity;

  factory Room.fromJson(Map<String, dynamic> j) => Room(
    id: j['id'].toString(),
    name: j['name'] as String,
    capacity: parseInt(j['capacity']) ?? 1,
  );
}

/// Slot jadwal (SlotPicker KS-06).
class Slot {
  const Slot({
    required this.startAt,
    required this.endAt,
    required this.available,
    this.unavailableReason,
    this.therapistIds = const [],
  });

  final DateTime startAt;
  final DateTime endAt;
  final bool available;
  final String? unavailableReason;
  final List<String> therapistIds;

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
    startAt: parseDate(j['start_at'])!,
    endAt: parseDate(j['end_at'])!,
    available: j['available'] as bool? ?? false,
    unavailableReason: j['unavailable_reason'] as String?,
    therapistIds: parseStrings(j['therapist_ids']),
  );
}

/// Permintaan pindah jadwal dari terapis (TR-01 → front desk).
class RescheduleRequest {
  const RescheduleRequest({
    required this.id,
    required this.sessionId,
    required this.patientName,
    required this.therapistName,
    required this.startAt,
    required this.reason,
    required this.requestedAt,
    this.proposal,
    this.handledAt,
    this.resolution,
  });

  final String id;
  final String sessionId;
  final String patientName;
  final String therapistName;
  final DateTime startAt;
  final String reason;
  final String? proposal;
  final DateTime requestedAt;
  final DateTime? handledAt;
  final String? resolution;

  factory RescheduleRequest.fromJson(Map<String, dynamic> j) =>
      RescheduleRequest(
        id: j['id'].toString(),
        sessionId: j['session_id'].toString(),
        patientName: j['patient_name'] as String,
        therapistName: j['therapist_name'] as String,
        startAt: parseDate(j['start_at'])!,
        reason: j['reason'] as String,
        proposal: j['proposal'] as String?,
        requestedAt: parseDate(j['requested_at'])!,
        handledAt: parseDate(j['handled_at']),
        resolution: j['resolution'] as String?,
      );
}

/// Blok jam tidak tersedia terapis (TR-02).
class TherapistBlock {
  const TherapistBlock({
    required this.id,
    required this.kind,
    this.startsAt,
    this.endsAt,
    this.weekday,
    this.startTime,
    this.endTime,
    this.note,
  });

  final String id;

  /// `once` | `weekly`
  final String kind;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// 1 = Senin … 7 = Minggu.
  final int? weekday;
  final String? startTime;
  final String? endTime;
  final String? note;

  factory TherapistBlock.fromJson(Map<String, dynamic> j) => TherapistBlock(
    id: j['id'].toString(),
    kind: j['kind'] as String,
    startsAt: parseDate(j['starts_at']),
    endsAt: parseDate(j['ends_at']),
    weekday: parseInt(j['weekday']),
    startTime: j['start_time'] as String?,
    endTime: j['end_time'] as String?,
    note: j['note'] as String?,
  );
}

enum LeaveStatus {
  pending('pending', 'Menunggu'),
  approved('approved', 'Disetujui'),
  rejected('rejected', 'Ditolak'),
  cancelled('cancelled', 'Dibatalkan');

  const LeaveStatus(this.api, this.label);
  final String api;
  final String label;

  static LeaveStatus fromApi(Object? v) =>
      values.where((s) => s.api == v).firstOrNull ?? LeaveStatus.pending;
}

/// Pengajuan cuti terapis (TR-03 → OW-06).
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.therapistId,
    required this.therapistName,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.affectedSessions,
    this.note,
    this.decisionReason,
  });

  final String id;
  final String therapistId;
  final String therapistName;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String reason;
  final String? note;
  final LeaveStatus status;
  final String? decisionReason;
  final DateTime createdAt;
  final int affectedSessions;

  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
    id: j['id'].toString(),
    therapistId: j['therapist_id'].toString(),
    therapistName: j['therapist_name'] as String? ?? '',
    startsAt: parseDate(j['starts_at'])!,
    endsAt: parseDate(j['ends_at'])!,
    allDay: j['all_day'] as bool? ?? true,
    reason: j['reason'] as String? ?? '',
    note: j['note'] as String?,
    status: LeaveStatus.fromApi(j['status']),
    decisionReason: j['decision_reason'] as String?,
    createdAt: parseDate(j['created_at']) ?? DateTime.now(),
    affectedSessions: parseInt(j['affected_sessions']) ?? 0,
  );
}

/// Permintaan reset password dari UM-06, ditangani owner (OW-06).
class PasswordResetRequest {
  const PasswordResetRequest({
    required this.id,
    required this.username,
    required this.createdAt,
    this.userId,
    this.name,
    this.note,
    this.handledAt,
    this.resolution,
  });

  final String id;
  final String username;
  final String? userId;
  final String? name;
  final String? note;
  final DateTime createdAt;
  final DateTime? handledAt;
  final String? resolution;

  factory PasswordResetRequest.fromJson(Map<String, dynamic> j) =>
      PasswordResetRequest(
        id: j['id'].toString(),
        username: j['username'] as String,
        userId: j['user_id']?.toString(),
        name: j['name'] as String?,
        note: j['note'] as String?,
        createdAt: parseDate(j['created_at'])!,
        handledAt: parseDate(j['handled_at']),
        resolution: j['resolution'] as String?,
      );
}

/// Anggota staf (OW-08).
class StaffMember {
  const StaffMember({
    required this.user,
    required this.isActive,
    this.phone,
    this.lastLoginAt,
  });

  final StaffUser user;
  final bool isActive;
  final String? phone;
  final DateTime? lastLoginAt;

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
    user: staffUserFromApi(j),
    isActive: j['is_active'] as bool? ?? true,
    phone: j['phone'] as String?,
    lastLoginAt: parseDate(j['last_login_at']),
  );
}

/// Detail cabang (OW-17): jam operasional per hari ISO, nomor WA, ruang.
class BranchDetail {
  const BranchDetail({
    required this.branch,
    required this.openingHours,
    required this.rooms,
    this.waNumber,
  });

  final Branch branch;

  /// "1" (Senin) … "7" (Minggu) → [buka, tutup]; hari tanpa kunci = tutup.
  final Map<String, List<String>> openingHours;
  final List<Room> rooms;
  final String? waNumber;

  factory BranchDetail.fromJson(Map<String, dynamic> j) => BranchDetail(
    branch: Branch(
      id: j['id'].toString(),
      name: j['name'] as String,
      address: j['address'] as String? ?? '',
    ),
    openingHours: {
      for (final e in ((j['opening_hours'] as Map?) ?? const {}).entries)
        e.key.toString(): parseStrings(e.value),
    },
    rooms: [
      for (final r in (j['rooms'] as List? ?? const []))
        Room.fromJson((r as Map).cast<String, dynamic>()),
    ],
    waNumber: j['wa_number'] as String?,
  );
}

/// Hasil pindah massal per sesi (KS-08).
class BulkMoveResult {
  const BulkMoveResult({
    required this.sessionId,
    required this.status,
    this.errors = const {},
    this.session,
  });

  final String sessionId;

  /// `moved` | `needs_action` | `failed`
  final String status;
  final Map<String, List<String>> errors;
  final Session? session;

  String? get firstError => errors.values.expand((e) => e).firstOrNull;

  factory BulkMoveResult.fromJson(Map<String, dynamic> j) => BulkMoveResult(
    sessionId: j['session_id'].toString(),
    status: j['status'] as String,
    errors: {
      for (final e in ((j['errors'] as Map?) ?? const {}).entries)
        e.key.toString(): parseStrings(e.value),
    },
    session: j['session'] == null
        ? null
        : Session.fromJson((j['session'] as Map).cast<String, dynamic>()),
  );
}

/// Halaman daftar dari paginator API.
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;
  bool get hasMore => page < lastPage;
}

/// Filter daftar pasien KS-03 / OW-03.
class PatientFilter {
  const PatientFilter({
    this.archived = false,
    this.hasPackage = false,
    this.away = false,
    this.unpaid = false,
  });

  final bool archived;
  final bool hasPackage;
  final bool away;
  final bool unpaid;

  Map<String, dynamic> toQuery() => {
    if (archived) 'archived': 'true',
    if (hasPackage) 'has_package': 'true',
    if (away) 'away': 'true',
    if (unpaid) 'unpaid': 'true',
  };
}

/// Paginasi pasien dipakai banyak layar.
typedef PatientPage = PageResult<Patient>;
