import '../models/models.dart';
import '../repositories/repositories.dart';

/// Sumber data server untuk operasi baca. Dua implementasi: [MockRemote] (data contoh di HP)
/// dan [HttpRemote] (One Lotus API). Operasi tulis lewat outbox → `OutboxSender`.
abstract interface class OneLotusRemote {
  Future<List<Session>> sessions({
    required String branchId,
    required DateTime from,
    required DateTime to,
    String? therapistId,
  });

  Future<Page<Patient>> searchPatients({
    required String query,
    required int page,
    required bool mineOnly,
  });
  Future<Patient> patient(String id);

  Future<SessionRecord?> recordForSession(String sessionId);
  Future<SessionRecord?> latestRecordForPatient(String patientId);
  Future<Page<SessionRecord>> recordHistory(
    String patientId, {
    required int page,
  });
  Future<List<LegacyRecord>> legacyRecords(String patientId);

  Future<List<Service>> services({required String branchId});
  Future<Invoice?> invoiceForSession(String sessionId);
}

/// Jenis operasi outbox — dipakai sender API & mock.
abstract final class OutboxKinds {
  static const sessionRecordUpsert = 'session_record.upsert';
  static const sessionStatus = 'session.status';
}
