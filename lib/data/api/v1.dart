import '../models/json.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Penerjemah kontrak One Lotus API v1 (backend Go, `backend/docs/openapi.yaml`) ↔ model aplikasi.
/// Model aplikasi tetap dipakai UI & cache lokal (toJson/fromJson); hanya batas API yang diterjemahkan di sini.
abstract final class V1 {
  /// Versi kebijakan privasi dari `GET /v1/app/config` (dikirim bersama persetujuan pasien).
  static String policyVersion = '';

  // ── Peran & cabang ────────────────────────────────────────────────────

  /// owner/admin → Owner, cashier → Kasir, therapist → Terapis. Admin klinik menunggu workshop (§18).
  static Role? role(String? r) => switch (r) {
    'owner' || 'admin' => Role.owner,
    'cashier' => Role.kasir,
    'therapist' => Role.terapis,
    _ => null,
  };

  static String roleApi(Role r) => switch (r) {
    Role.owner => 'owner',
    Role.kasir => 'cashier',
    Role.terapis => 'therapist',
  };

  /// `GET /v1/me` → StaffUser. Peran = gabungan peran di semua cabang; alamat cabang dari `GET /v1/branches`.
  static StaffUser me(Map<String, dynamic> m, {Map<String, Branch> branches = const {}}) {
    final roles = <Role>[];
    final br = <String, Branch>{};
    for (final a in (m['roles'] as List? ?? const [])) {
      final r = asMap(a);
      final role = V1.role(r['role'] as String?);
      if (role != null && !roles.contains(role)) roles.add(role);
      final id = r['branch_id'].toString();
      br[id] = branches[id] ??
          Branch(id: id, name: r['branch_name'] as String? ?? 'Cabang', address: '');
    }
    roles.sort((a, b) => a.index.compareTo(b.index));
    return StaffUser(
      id: m['id'].toString(),
      username: m['username'] as String? ?? '',
      name: m['name'] as String,
      roles: roles,
      branches: br.values.toList(),
      mustChangePassword: m['must_change_password'] as bool? ?? false,
    );
  }

  static StaffMember staff(Map<String, dynamic> m) {
    final roles = <Role>[];
    final br = <String, Branch>{};
    for (final a in (m['roles'] as List? ?? const [])) {
      final r = asMap(a);
      final role = V1.role(r['role'] as String?);
      if (role != null && !roles.contains(role)) roles.add(role);
      final id = r['branch_id'].toString();
      br[id] = Branch(id: id, name: r['branch_name'] as String? ?? 'Cabang', address: '');
    }
    return StaffMember(
      user: StaffUser(
        id: m['id'].toString(),
        username: m['username'] as String? ?? '',
        name: m['name'] as String,
        roles: roles,
        branches: br.values.toList(),
      ),
      isActive: m['status'] == 'active',
      phone: m['phone'] as String?,
      lastLoginAt: parseDate(m['last_login_at']),
    );
  }

  /// StaffInput: peran per cabang = semua kombinasi [roles] × [branchIds].
  static Map<String, dynamic> staffInput({
    required String name,
    required String username,
    required List<Role> roles,
    required List<String> branchIds,
    String? phone,
  }) => {
    'name': name,
    'username': username,
    'phone': phone,
    'roles': [
      for (final b in branchIds)
        for (final r in roles) {'branch_id': b, 'role': roleApi(r)},
    ],
  };

  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  /// Branch API → BranchDetail. Jam buka `{"mon":[["08:00","20:00"]]}` → `{"1":["08:00","20:00"]}`.
  static BranchDetail branch(Map<String, dynamic> j) {
    final hours = <String, List<String>>{};
    final oh = (j['opening_hours'] as Map?) ?? const {};
    for (var i = 0; i < 7; i++) {
      final ranges = oh[_days[i]];
      if (ranges is List && ranges.isNotEmpty && ranges.first is List) {
        hours['${i + 1}'] = parseStrings(ranges.first);
      }
    }
    return BranchDetail(
      branch: Branch(
        id: j['id'].toString(),
        name: j['name'] as String,
        address: j['address'] as String? ?? '',
      ),
      openingHours: hours,
      rooms: [
        for (final r in (j['rooms'] as List? ?? const []))
          Room.fromJson(asMap(r)),
      ],
      waNumber: j['phone_wa'] as String?,
    );
  }

  static Map<String, dynamic> openingHours(Map<String, List<String>> h) => {
    for (final e in h.entries)
      if (int.tryParse(e.key) case final d? when d >= 1 && d <= 7 && e.value.length == 2)
        _days[d - 1]: [e.value],
  };

  // ── Pasien ────────────────────────────────────────────────────────────

  static Gender? gender(Object? g) => switch (g) {
    'male' => Gender.male,
    'female' => Gender.female,
    _ => null,
  };

  static String genderApi(Gender g) => g == Gender.male ? 'male' : 'female';

  /// PatientListItem → Patient (HP sudah disamarkan server bila tidak berwenang).
  static Patient patientItem(Map<String, dynamic> j) {
    final pkg = j['active_package'] is Map ? asMap(j['active_package']) : null;
    final remaining = parseInt(pkg?['remaining']) ?? 0;
    return Patient(
      id: j['id'].toString(),
      number: parseInt(j['number']) ?? 0,
      name: j['name'] as String,
      gender: gender(j['gender']),
      phone: j['phone_masked'] as String?,
      lastVisitAt: parseDate(j['last_visit_at']),
      activePackage: pkg == null
          ? null
          : PackageSummary(
              name: pkg['name'] as String? ?? 'Paket',
              remaining: remaining,
              total: remaining,
            ),
      archivedAt: j['is_archived'] == true ? DateTime.now() : null,
    );
  }

  static Patient patient(Map<String, dynamic> j, {Map<String, dynamic>? overview}) {
    PackageSummary? pkg;
    for (final p in (overview?['packages'] as List? ?? const [])) {
      final m = asMap(p);
      if (m['status'] != 'active') continue;
      pkg = PackageSummary(
        name: (m['package'] is Map ? asMap(m['package'])['name'] : null) as String? ?? 'Paket',
        remaining: parseInt(m['remaining']) ?? 0,
        total: parseInt(m['sessions_total']) ?? 0,
        expiresAt: parseDate(m['expires_on']),
      );
      break;
    }
    final birth = j['birth_date'] as String?;
    return Patient(
      id: j['id'].toString(),
      number: parseInt(j['number']) ?? 0,
      name: j['name'] as String,
      // Data lama tanpa tanggal lahir dikirim "0001-01-01".
      birthDate: birth == null || birth.startsWith('0001') ? null : DateTime.tryParse(birth),
      birthPlace: j['birth_place'] as String?,
      phone: j['phone'] as String?,
      address: j['address'] as String?,
      gender: gender(j['gender']),
      institution: j['occupation'] as String?,
      hobby: j['hobby'] as String?,
      heightCm: parseDouble(j['height_cm']),
      weightKg: parseDouble(j['weight_kg']),
      medicalAlert: j['medical_alert'] as String?,
      activePackage: pkg,
      archivedAt: j['is_archived'] == true ? parseDate(j['updated_at']) : null,
    );
  }

  /// PatientDraft (KS-04) → PatientInput.
  static Map<String, dynamic> patientInput(PatientDraft d, {bool force = false}) => {
    'name': d.name,
    'birth_date': formatDay(d.birthDate),
    'gender': genderApi(d.gender),
    'phone': d.phone,
    'birth_place': d.birthPlace,
    'address': d.address,
    'occupation': d.institution,
    'hobby': d.hobby,
    'height_cm': d.heightCm,
    'weight_kg': d.weightKg,
    if (d.healthConsent)
      'consent': {
        'policy_version': policyVersion.isEmpty ? 'staff' : policyVersion,
        'health_data': true,
        'reminders': true,
      },
    'force_create': force,
  };

  /// Kandidat `duplicate_patient` → bentuk lama sheet ST-08 (`match`, `birth_date`).
  static Map<String, dynamic> duplicateCandidate(Map<String, dynamic> c) {
    final p = c['patient'] is Map ? asMap(c['patient']) : c;
    final on = parseStrings(c['match_on']);
    return {
      'id': p['id'],
      'number': p['number'],
      'name': p['name'],
      'birth_date': p['birth_date'],
      'match': on.contains('name_birth_date') ? 'name_birth_date' : 'phone',
    };
  }

  // ── Sesi ──────────────────────────────────────────────────────────────

  /// Status API + status tagihan → status tampilan (§6.2): selesai & belum lunas = "Belum bayar".
  static SessionStatus sessionStatus(String? status, String? payment) => switch (status) {
    'pending_confirmation' => SessionStatus.awaitingConfirmation,
    'scheduled' => SessionStatus.scheduled,
    'arrived' => SessionStatus.arrived,
    'in_progress' => SessionStatus.running,
    'completed' => switch (payment) {
      'paid' => SessionStatus.paid,
      'unpaid' || 'awaiting_payment' || 'partially_paid' => SessionStatus.unpaid,
      _ => SessionStatus.done,
    },
    'no_show' => SessionStatus.noShow,
    'cancelled' => SessionStatus.cancelled,
    _ => SessionStatus.scheduled,
  };

  /// Status tujuan → aksi transisi (§7.1).
  static String? transitionFor(SessionStatus s) => switch (s) {
    SessionStatus.scheduled => 'confirm',
    SessionStatus.arrived => 'arrive',
    SessionStatus.running => 'start',
    SessionStatus.done => 'complete',
    SessionStatus.noShow => 'no_show',
    SessionStatus.cancelled => 'cancel',
    _ => null,
  };

  static Session session(Map<String, dynamic> j) {
    final p = asMap(j['patient']);
    final sv = asMap(j['service'] ?? const {});
    final t = j['therapist'] is Map ? asMap(j['therapist']) : const <String, dynamic>{};
    final start = parseDate(j['scheduled_start'])!;
    final end = parseDate(j['scheduled_end']);
    final addr = j['address'] is Map ? asMap(j['address']) : null;
    return Session(
      id: j['id'].toString(),
      patientId: p['id'].toString(),
      patientName: p['name'] as String,
      patientNumber: parseInt(p['number']) ?? 0,
      therapistId: t['id']?.toString() ?? '',
      therapistName: t['name'] as String? ?? '—',
      serviceId: sv['id']?.toString() ?? '',
      serviceName: sv['name'] as String? ?? '',
      branchId: j['branch_id']?.toString() ?? '',
      startAt: start,
      durationMin: end != null ? end.difference(start).inMinutes : (parseInt(sv['duration_min']) ?? 60),
      status: sessionStatus(j['status'] as String?, j['payment_status'] as String?),
      room: j['room'] is Map ? asMap(j['room'])['name'] as String? : null,
      homeVisit: j['location_type'] == 'home_visit'
          ? HomeVisit(
              address: addr?['text'] as String? ?? '',
              landmark: addr?['landmark'] as String?,
              lat: parseDouble(addr?['lat']),
              lng: parseDouble(addr?['lng']),
            )
          : null,
      isNewPatient: j['is_new_patient'] as bool? ?? false,
      note: j['status_reason'] as String?,
      startedAt: parseDate(j['started_at']),
      endedAt: parseDate(j['ended_at']),
      needsAction: j['needs_action'] as bool? ?? false,
    );
  }

  static Slot slot(Map<String, dynamic> j) => Slot(
    startAt: parseDate(j['start'])!,
    endAt: parseDate(j['end'])!,
    available: j['available'] as bool? ?? false,
    therapistIds: parseStrings(j['therapist_ids']),
  );

  // ── Rekam sesi ────────────────────────────────────────────────────────

  static const _sideApi = {'left': 'l', 'right': 'r', 'common': 'c'};
  static const _sideApp = {'l': 'left', 'r': 'right', 'c': 'common'};

  static String _joinTags(List<String> tags, String text) =>
      [if (tags.isNotEmpty) tags.join(', '), if (text.trim().isNotEmpty) text.trim()].join('\n');

  /// SessionRecord (aplikasi) → SessionRecordInput. Tag analisa/kesimpulan digabung ke teksnya.
  static Map<String, dynamic> recordInput(SessionRecord r) {
    List<Map<String, String>> areas(List<String> keys, String mode) => [
      for (final k in keys)
        if (k.split(':') case [final slug, final side])
          {'area_code': slug, 'side': _sideApi[side] ?? 'c', 'mode': mode},
    ];
    final analysis = _joinTags(r.analysisTags, r.analysis);
    final conclusion = _joinTags(r.conclusionTags, r.conclusion);
    return {
      'complaint': r.complaint,
      'cause': r.cause?.name,
      'cause_note': r.causeNote,
      'injury_duration_value': r.injuryDuration,
      'injury_duration_unit': r.injuryDurationUnit?.name,
      'body_areas': [...areas(r.treatedAreas, 'treated'), ...areas(r.calmingAreas, 'calming')],
      'pain_before': r.painBefore,
      'pain_after': r.painAfter,
      'analysis': analysis.isEmpty ? null : analysis,
      'treatments': r.treatments,
      'treatment_note': r.treatmentNote.isEmpty ? null : r.treatmentNote,
      'conclusion': conclusion.isEmpty ? null : conclusion,
      'client_updated_at': formatDate(r.updatedAt),
    };
  }

  static SessionRecord record(
    Map<String, dynamic> j, {
    required String id,
    required String patientId,
    required String therapistId,
  }) {
    final treated = <String>[], calming = <String>[];
    for (final a in (j['body_areas'] as List? ?? const [])) {
      final m = asMap(a);
      final key = '${m['area_code']}:${_sideApp[m['side']] ?? 'common'}';
      (m['mode'] == 'calming' ? calming : treated).add(key);
    }
    final by = j['created_by'] is Map ? asMap(j['created_by']) : const <String, dynamic>{};
    return SessionRecord(
      id: id,
      sessionId: j['session_id'].toString(),
      patientId: patientId,
      therapistId: by['id']?.toString() ?? therapistId,
      complaint: j['complaint'] as String? ?? '',
      cause: InjuryCause.values.where((c) => c.name == j['cause']).firstOrNull,
      causeNote: j['cause_note'] as String?,
      injuryDuration: parseInt(j['injury_duration_value']),
      injuryDurationUnit: DurationUnit.fromApi(j['injury_duration_unit']),
      treatedAreas: treated,
      calmingAreas: calming,
      painBefore: parseInt(j['pain_before']),
      painAfter: parseInt(j['pain_after']),
      analysis: j['analysis'] as String? ?? '',
      treatments: parseStrings(j['treatments']),
      treatmentNote: j['treatment_note'] as String? ?? '',
      conclusion: j['conclusion'] as String? ?? '',
      attachments: [
        for (final a in (j['attachments'] as List? ?? const []))
          if (AttachmentKind.values.where((k) => k.name == asMap(a)['kind']).firstOrNull
              case final kind?)
            Attachment(
              id: asMap(a)['id'].toString(),
              kind: kind,
              uploadState: asMap(a)['status'] == 'uploaded'
                  ? UploadState.uploaded
                  : asMap(a)['status'] == 'failed'
                  ? UploadState.failed
                  : UploadState.pending,
            ),
      ],
      version: parseInt(j['version']) ?? 0,
      updatedAt: parseDate(j['updated_at']),
    );
  }

  static const _legacyLabels = {
    'complaint': 'Keluhan',
    'cause': 'Penyebab',
    'injury_duration': 'Lama cedera',
    'area': 'Bagian',
    'calming_area': 'Bagian penenang',
    'analysis': 'Analisa',
    'treatment': 'Treatment',
    'conclusion': 'Kesimpulan',
    'therapist_name': 'Terapis',
    'xray_url': 'Hasil rontgen',
  };

  static LegacyRecord legacy(Map<String, dynamic> j) => LegacyRecord(
    date: parseDate(j['record_date']) ?? DateTime(1970),
    fields: {
      for (final e in _legacyLabels.entries)
        if ((j[e.key] as String?)?.trim().isNotEmpty ?? false) e.value: (j[e.key] as String).trim(),
    },
  );

  // ── Jadwal terapis ────────────────────────────────────────────────────

  static const _byDay = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  static TherapistBlock block(Map<String, dynamic> j) {
    final rrule = j['rrule'] as String?;
    final starts = parseDate(j['starts_at']);
    final ends = parseDate(j['ends_at']);
    String hm(DateTime? d) => d == null
        ? ''
        : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (rrule != null && rrule.contains('WEEKLY')) {
      final day = RegExp(r'BYDAY=(\w\w)').firstMatch(rrule)?.group(1);
      return TherapistBlock(
        id: j['id'].toString(),
        kind: 'weekly',
        weekday: day == null ? starts?.weekday : _byDay.indexOf(day) + 1,
        startTime: hm(starts),
        endTime: hm(ends),
        note: j['reason'] as String?,
      );
    }
    return TherapistBlock(
      id: j['id'].toString(),
      kind: 'once',
      startsAt: starts,
      endsAt: ends,
      note: j['reason'] as String?,
    );
  }

  /// Blok mingguan → kejadian pertama + RRULE.
  static Map<String, dynamic> blockInput({
    required String kind,
    DateTime? startsAt,
    DateTime? endsAt,
    int? weekday,
    String? startTime,
    String? endTime,
    String? note,
  }) {
    if (kind == 'weekly' && weekday != null && startTime != null && endTime != null) {
      final now = DateTime.now();
      var day = DateTime(now.year, now.month, now.day);
      while (day.weekday != weekday) {
        day = day.add(const Duration(days: 1));
      }
      DateTime at(String hm) {
        final [h, m] = hm.split(':').map(int.parse).toList();
        return DateTime(day.year, day.month, day.day, h, m);
      }

      return {
        'starts_at': formatDate(at(startTime)),
        'ends_at': formatDate(at(endTime)),
        'rrule': 'FREQ=WEEKLY;BYDAY=${_byDay[weekday - 1]}',
        'reason': note,
      };
    }
    return {
      'starts_at': formatDate(startsAt),
      'ends_at': formatDate(endsAt),
      'reason': note,
    };
  }

  static LeaveRequest leave(
    Map<String, dynamic> j, {
    String therapistId = '',
    String therapistName = '',
  }) => LeaveRequest(
    id: j['id'].toString(),
    therapistId: therapistId,
    therapistName: therapistName,
    startsAt: parseDate(j['starts_at'])!,
    endsAt: parseDate(j['ends_at'])!,
    allDay: j['all_day'] as bool? ?? true,
    reason: j['reason_code'] as String? ?? '',
    note: j['note'] as String?,
    status: LeaveStatus.fromApi(j['status']),
    createdAt: parseDate(j['created_at']) ?? DateTime.now(),
    affectedSessions: parseInt(j['affected_sessions']) ?? 0,
  );

  /// Approval jenis `leave` (OW-06) → LeaveRequest.
  static LeaveRequest leaveApproval(Map<String, dynamic> a) {
    final p = asMap(a['payload'] ?? const {});
    final by = a['requested_by'] is Map ? asMap(a['requested_by']) : const <String, dynamic>{};
    return LeaveRequest(
      id: a['id'].toString(),
      therapistId: by['id']?.toString() ?? '',
      therapistName: p['staff_name'] as String? ?? by['name'] as String? ?? '',
      startsAt: parseDate(p['starts_at']) ?? DateTime.now(),
      endsAt: parseDate(p['ends_at']) ?? DateTime.now(),
      allDay: p['all_day'] as bool? ?? true,
      reason: p['reason_code'] as String? ?? '',
      note: p['note'] as String?,
      status: switch (a['status']) {
        'approved' => LeaveStatus.approved,
        'rejected' => LeaveStatus.rejected,
        _ => LeaveStatus.pending,
      },
      decisionReason: a['reason'] as String?,
      createdAt: parseDate(a['created_at']) ?? DateTime.now(),
      affectedSessions: parseInt(p['affected_sessions']) ?? 0,
    );
  }

  /// Approval jenis `password_reset` → PasswordResetRequest.
  static PasswordResetRequest passwordReset(Map<String, dynamic> a) {
    final p = asMap(a['payload'] ?? const {});
    return PasswordResetRequest(
      id: a['id'].toString(),
      username: p['username'] as String? ?? '',
      userId: a['subject_id']?.toString(),
      name: p['staff_name'] as String?,
      note: (p['note'] as String?)?.isEmpty ?? true ? null : p['note'] as String,
      createdAt: parseDate(a['created_at']) ?? DateTime.now(),
      handledAt: parseDate(a['decided_at']),
      resolution: a['status'] == 'pending' ? null : a['status'] as String?,
    );
  }
}
