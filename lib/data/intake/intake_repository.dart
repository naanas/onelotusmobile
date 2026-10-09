import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../ui/feedback/app_error.dart';
import '../api/api_client.dart';
import '../api/api_error_mapper.dart';
import '../models/models.dart';
import '../providers.dart';

/// Pendaftaran pasien baru di front desk: intake QR (WB-01 → KS-02) dan tambah manual (KS-04).
/// Endpoint: docs/api-kontrak.md bagian "Intake pasien baru".
abstract interface class PatientIntakeRepository {
  /// Tautan QR form intake cabang.
  Future<IntakeLink> link(String branchId);

  /// "Ganti QR": kode lama langsung tidak berlaku.
  Future<IntakeLink> rotateLink(String branchId);

  /// Kiriman yang belum diproses, terbaru dulu.
  Future<List<IntakeSummary>> pending(String branchId);

  Future<IntakeDetail> detail(String id);
  Future<Uint8List> attachment(String intakeId, String attachmentId);

  /// Verifikasi → pasien baru (nomor dari server) atau gabung ke [existingPatientId].
  /// Melempar [DuplicatePatientError] bila ada pasien mirip dan belum dikonfirmasi.
  Future<Patient> process(
    String id,
    PatientDraft draft, {
    bool confirmNotDuplicate = false,
    String? existingPatientId,
  });

  /// Buang kiriman (iseng, ganda, pasien batal) — alasan wajib.
  Future<void> discard(String id, String reason);

  /// Tambah pasien manual (KS-04 tanpa intake).
  Future<Patient> create(
    PatientDraft draft, {
    bool confirmNotDuplicate = false,
  });
}

final patientIntakeRepositoryProvider = Provider<PatientIntakeRepository>(
  (ref) => AppConfig.useMock
      ? MockPatientIntakeRepository()
      : HttpPatientIntakeRepository(ref.watch(apiClientProvider)),
);

class HttpPatientIntakeRepository implements PatientIntakeRepository {
  HttpPatientIntakeRepository(this.api);

  final ApiClient api;

  @override
  Future<IntakeLink> link(String branchId) => api.get(
    '/v1/branches/$branchId/intake-link',
    (d) => IntakeLink.fromJson(asMap(d)),
  );

  @override
  Future<IntakeLink> rotateLink(String branchId) => api.post(
    '/v1/branches/$branchId/intake-link/rotate',
    null,
    (d) => IntakeLink.fromJson(asMap(d)),
  );

  @override
  Future<List<IntakeSummary>> pending(String branchId) => api.get(
    '/v1/intake',
    (d) => parseList(d, IntakeSummary.fromJson),
    query: {'branch_id': branchId, 'status': 'new'},
  );

  @override
  Future<IntakeDetail> detail(String id) =>
      api.get('/v1/intake/$id', (d) => IntakeDetail.fromJson(asMap(d)));

  @override
  Future<Uint8List> attachment(String intakeId, String attachmentId) async {
    try {
      final res = await api.dio.get<List<int>>(
        '/v1/intake/$intakeId/attachments/$attachmentId',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<Patient> process(
    String id,
    PatientDraft draft, {
    bool confirmNotDuplicate = false,
    String? existingPatientId,
  }) => api.post('/v1/intake/$id/process', {
    ...draft.toJson(),
    'confirm_not_duplicate': confirmNotDuplicate,
    'existing_patient_id': ?existingPatientId,
  }, (d) => Patient.fromJson(asMap(d)));

  @override
  Future<void> discard(String id, String reason) =>
      api.post('/v1/intake/$id/discard', {'reason': reason}, (_) {});

  @override
  Future<Patient> create(
    PatientDraft draft, {
    bool confirmNotDuplicate = false,
  }) => api.post('/v1/patients', {
    ...draft.toJson(),
    'confirm_not_duplicate': confirmNotDuplicate,
  }, (d) => Patient.fromJson(asMap(d)));
}

/// Mode mock (API_URL kosong): data contoh di memori, perilaku sama dengan API.
class MockPatientIntakeRepository implements PatientIntakeRepository {
  MockPatientIntakeRepository({DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    final now = _now();
    _items = [
      _demo(
        'i1',
        'A-07',
        'Sari Wulandari',
        now.subtract(const Duration(minutes: 12)),
        complaint: 'Nyeri pinggang bawah, makin terasa setelah duduk lama.',
        birth: DateTime(1994, 2, 14),
        phone: '0812 7788 2104',
        gender: Gender.female,
        height: 162,
        weight: 55,
      ),
      _demo(
        'i2',
        'A-03',
        'Rizky Hakim',
        now.subtract(const Duration(hours: 27)),
        complaint: 'Lutut kanan sakit setelah futsal.',
        birth: DateTime(2001, 8, 3),
        phone: '0857 1122 3344',
        gender: Gender.male,
      ),
    ];
  }

  final DateTime Function() _now;
  late List<IntakeDetail> _items;
  int _code = 1;
  int _nextNumber = 413;

  static IntakeDetail _demo(
    String id,
    String queue,
    String name,
    DateTime at, {
    required String complaint,
    required DateTime birth,
    required String phone,
    required Gender gender,
    int? height,
    int? weight,
  }) => IntakeDetail(
    summary: IntakeSummary(
      id: id,
      queueLabel: queue,
      name: name,
      complaint: complaint,
      bodyComplete: height != null && weight != null,
      attachmentCount: 0,
      status: IntakeStatus.pending,
      stale: DateTime.now().difference(at) > const Duration(hours: 24),
      createdAt: at,
    ),
    birthDate: birth,
    gender: gender,
    phone: phone,
    birthPlace: 'Malang',
    address: 'Jl. Bunga Kopi No. 8, Lowokwaru',
    institution: 'Guru SD',
    hobby: 'Yoga',
    heightCm: height,
    weightKg: weight,
    cause: IntakeCause.kerja,
    injuryDuration: 2,
    injuryDurationUnit: 'week',
  );

  IntakeLink get _link => IntakeLink(
    code: 'demo$_code',
    url: 'https://onelotuspt.com/intake/demo$_code',
  );

  Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  @override
  Future<IntakeLink> link(String branchId) async {
    await _delay();
    return _link;
  }

  @override
  Future<IntakeLink> rotateLink(String branchId) async {
    await _delay();
    _code++;
    return _link;
  }

  @override
  Future<List<IntakeSummary>> pending(String branchId) async {
    await _delay();
    return [
      for (final i in _items)
        if (i.summary.status == IntakeStatus.pending) i.summary,
    ];
  }

  IntakeDetail _find(String id) => _items.firstWhere(
    (i) => i.id == id,
    orElse: () => throw const AppError(ErrorCode.notFound),
  );

  @override
  Future<IntakeDetail> detail(String id) async {
    await _delay();
    return _find(id);
  }

  @override
  Future<Uint8List> attachment(String intakeId, String attachmentId) async =>
      throw const AppError(ErrorCode.notFound);

  void _done(String id) => _items = [
    for (final i in _items)
      if (i.id != id) i,
  ];

  /// Contoh pasien ganda (ST-08): "Sari Wulandari" sudah ada sebagai #0291.
  void _checkDuplicate(PatientDraft d, bool confirmed) {
    if (!confirmed && d.name.trim().toLowerCase() == 'sari wulandari') {
      throw DuplicatePatientError(
        candidates: [
          {
            'id': 'p0291',
            'number': 291,
            'name': 'Sari Wulandari',
            'birth_date': '1994-02-14',
            'match': 'name_birth_date',
          },
        ],
      );
    }
  }

  Patient _patient(PatientDraft d) => Patient(
    id: 'p$_nextNumber',
    number: _nextNumber++,
    name: d.name,
    birthDate: d.birthDate,
    gender: d.gender,
    phone: d.phone,
    address: d.address,
  );

  @override
  Future<Patient> process(
    String id,
    PatientDraft draft, {
    bool confirmNotDuplicate = false,
    String? existingPatientId,
  }) async {
    await _delay();
    _find(id);
    if (existingPatientId != null) {
      _done(id);
      return Patient(id: existingPatientId, number: 291, name: draft.name);
    }
    _checkDuplicate(draft, confirmNotDuplicate);
    _done(id);
    return _patient(draft);
  }

  @override
  Future<void> discard(String id, String reason) async {
    await _delay();
    _find(id);
    _done(id);
  }

  @override
  Future<Patient> create(
    PatientDraft draft, {
    bool confirmNotDuplicate = false,
  }) async {
    await _delay();
    _checkDuplicate(draft, confirmNotDuplicate);
    return _patient(draft);
  }
}

/// Ringkasan kandidat pasien ganda untuk sheet ST-08.
String duplicateDetail(Map<String, dynamic> c) {
  final birth = DateTime.tryParse(c['birth_date']?.toString() ?? '');
  final match = c['match'] == 'phone'
      ? 'nomor HP sama'
      : 'nama & tanggal lahir sama';
  return [if (birth != null) Fmt.dateNoDay(birth), match].join(' · ');
}
