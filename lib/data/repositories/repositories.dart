import '../models/models.dart';

/// Satu halaman hasil (ListPaging §4: 20 per halaman).
class Page<T> {
  const Page({required this.items, required this.page, required this.hasMore});

  final List<T> items;
  final int page;
  final bool hasMore;

  static const size = 20;
}

/// Data yang mungkin diambil dari cache lokal karena offline (§8).
class Fetched<T> {
  const Fetched(this.data, {this.stale = false, this.fetchedAt});

  final T data;

  /// true = dari cache HP, bukan dari server barusan.
  final bool stale;
  final DateTime? fetchedAt;
}

abstract interface class ScheduleRepository {
  /// Sesi satu hari di cabang; [therapistId] null = semua terapis (kasir/owner).
  Future<Fetched<List<Session>>> sessionsForDay({
    required String branchId,
    required DateTime day,
    String? therapistId,
  });

  /// Rentang tanggal (TR-02 jadwal minggu).
  Future<Fetched<List<Session>>> sessionsForRange({
    required String branchId,
    required DateTime from,
    required DateTime to,
    String? therapistId,
  });

  /// Ubah status sesi (hadir, mulai, selesai, tidak datang). Disimpan lewat outbox.
  Future<Session> updateStatus(
    Session session,
    SessionStatus status, {
    String? reason,
  });
}

abstract interface class PatientRepository {
  /// Cari nama, nomor (`0412` / `#0412`), atau 4 digit akhir HP (§4 SearchBar).
  /// [mineOnly] = pasien yang pernah ditangani terapis login (TR-06).
  Future<Page<Patient>> search({
    String query = '',
    int page = 1,
    bool mineOnly = false,
  });

  Future<Fetched<Patient>> byId(String id);
}

abstract interface class SessionRecordRepository {
  /// Rekam sesi untuk satu sesi (null bila belum ada).
  Future<SessionRecord?> forSession(String sessionId);

  /// Rekam sesi terakhir pasien — untuk prefill (§5.2).
  Future<SessionRecord?> latestForPatient(String patientId);

  /// Riwayat rekam sesi pasien, terbaru dulu.
  Future<Page<SessionRecord>> historyForPatient(
    String patientId, {
    int page = 1,
  });

  /// Catatan lama sistem Laravel (§5.3, ditampilkan apa adanya).
  Future<List<LegacyRecord>> legacyForPatient(String patientId);

  /// Draf autosave lokal (§5.2) — tidak dikirim ke server.
  Future<SessionRecord?> loadDraft(String sessionId);
  Future<void> saveDraft(SessionRecord record);
  Future<void> deleteDraft(String sessionId);

  /// Simpan final: masuk outbox, terkirim saat ada sinyal. Draf dihapus.
  Future<void> submit(SessionRecord record);
}

abstract interface class ServiceRepository {
  Future<Fetched<List<Service>>> services({required String branchId});
}

abstract interface class InvoiceRepository {
  Future<Invoice?> forSession(String sessionId);
}
