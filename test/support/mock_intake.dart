import 'dart:typed_data';

import 'package:onelotus_staff/data/api/api_error_mapper.dart';
import 'package:onelotus_staff/data/intake/intake_form_repository.dart';
import 'package:onelotus_staff/data/intake/intake_repository.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

// Pengganti repository intake untuk tes (tanpa server).

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

/// Mode mock: kode `invalid` = QR tidak berlaku; selain itu Klinik Pusat Malang.
class MockIntakeFormRepository implements IntakeFormRepository {
  int _queue = 6;
  final _sent = <String, IntakeReceipt>{};

  @override
  Future<String> branchName(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code == 'invalid') throw const AppError(ErrorCode.notFound);
    return 'Klinik Pusat Malang';
  }

  @override
  Future<IntakeReceipt> submit(String code, IntakeSubmission s) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (code == 'invalid') throw const AppError(ErrorCode.notFound);
    return _sent[s.clientId] ??= IntakeReceipt(
      queueLabel: 'A-${(++_queue).toString().padLeft(2, '0')}',
      firstName: s.name.trim().split(RegExp(r'\s+')).first,
    );
  }
}
