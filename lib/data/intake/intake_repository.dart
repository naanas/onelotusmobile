import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
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
  (ref) => HttpPatientIntakeRepository(ref.watch(apiClientProvider)),
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

/// Ringkasan kandidat pasien ganda untuk sheet ST-08.
String duplicateDetail(Map<String, dynamic> c) {
  final birth = DateTime.tryParse(c['birth_date']?.toString() ?? '');
  final match = c['match'] == 'phone'
      ? 'nomor HP sama'
      : 'nama & tanggal lahir sama';
  return [if (birth != null) Fmt.dateNoDay(birth), match].join(' · ');
}
