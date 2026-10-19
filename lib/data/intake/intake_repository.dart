import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../api/api_client.dart';
import '../../ui/feedback/app_error.dart';
import '../api/api_error_mapper.dart';
import '../api/v1.dart';
import 'intake_form_repository.dart' show intakeLinkPrefix;
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
  (ref) => HttpPatientIntakeRepository(ref.watch(apiClientProvider)),
);

class HttpPatientIntakeRepository implements PatientIntakeRepository {
  HttpPatientIntakeRepository(this.api);

  final ApiClient api;

  /// Kiriman terakhir yang dimuat (API v1 tidak punya `GET /v1/intake/{id}`).
  final _cache = <String, IntakeDetail>{};

  static IntakeLink _link(dynamic d) {
    final token = asMap(d)['token'] as String;
    return IntakeLink(code: token, url: '$intakeLinkPrefix$token');
  }

  @override
  Future<IntakeLink> link(String branchId) =>
      api.get('/v1/branches/$branchId/intake-token', _link);

  @override
  Future<IntakeLink> rotateLink(String branchId) =>
      api.post('/v1/branches/$branchId/intake-token/rotate', null, _link);

  @override
  Future<List<IntakeSummary>> pending(String branchId) async {
    final list = await api.get('/v1/intake', (d) => parseList(d, V1.intake), query: {'status': 'new'});
    for (final d in list) {
      _cache[d.id] = d;
    }
    return [for (final d in list) d.summary];
  }

  @override
  Future<IntakeDetail> detail(String id) async {
    if (_cache[id] case final d?) return d;
    await pending('');
    return _cache[id] ?? (throw const AppError(ErrorCode.notFound));
  }

  /// Rontgen dari form: signed URL (5 menit) lalu unduh langsung dari Storage.
  @override
  Future<Uint8List> attachment(String intakeId, String attachmentId) async {
    final url = await api.get('/v1/attachments/$attachmentId/url', (d) => asMap(d)['url'] as String);
    try {
      final res = await Dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  static Patient _patient(dynamic d) => V1.patient(asMap(asMap(d)['patient']));

  @override
  Future<Patient> process(
    String id,
    PatientDraft draft, {
    bool confirmNotDuplicate = false,
    String? existingPatientId,
  }) async {
    try {
      return await api.post(
        '/v1/intake/$id/process',
        existingPatientId != null
            ? {'action': 'link_existing', 'existing_patient_id': existingPatientId}
            : {'action': 'create_patient', 'patient': V1.patientInput(draft, force: confirmNotDuplicate)},
        _patient,
      );
    } on DuplicatePatientError catch (e) {
      throw DuplicatePatientError(candidates: [for (final c in e.candidates) V1.duplicateCandidate(c)], refId: e.refId);
    }
  }

  @override
  Future<void> discard(String id, String reason) =>
      api.post('/v1/intake/$id/process', {'action': 'reject', 'reason': reason}, (_) {});

  @override
  Future<Patient> create(PatientDraft draft, {bool confirmNotDuplicate = false}) async {
    try {
      return await api.post(
        '/v1/patients',
        V1.patientInput(draft, force: confirmNotDuplicate),
        (d) => V1.patient(asMap(d)),
      );
    } on DuplicatePatientError catch (e) {
      throw DuplicatePatientError(candidates: [for (final c in e.candidates) V1.duplicateCandidate(c)], refId: e.refId);
    }
  }
}

/// Ringkasan kandidat pasien ganda untuk sheet ST-08.
String duplicateDetail(Map<String, dynamic> c) {
  final birth = DateTime.tryParse(c['birth_date']?.toString() ?? '');
  final match = c['match'] == 'phone' || (c['match_on'] is List && !(c['match_on'] as List).contains('name_birth_date'))
      ? 'nomor HP sama'
      : 'nama & tanggal lahir sama';
  return [if (birth != null) Fmt.dateNoDay(birth), match].join(' · ');
}
