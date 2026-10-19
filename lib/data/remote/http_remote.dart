import '../../ui/feedback/app_error.dart';
import '../api/api_client.dart';
import '../api/api_error_mapper.dart';
import '../api/v1.dart';
import '../models/json.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../sync/outbox.dart';
import '../sync/sync_engine.dart';
import 'remote.dart';

/// [OneLotusRemote] ke One Lotus API v1 (`backend/docs/openapi.yaml`). Cabang aktif dikirim lewat header
/// `X-Branch-Id` oleh [ApiClient].
class HttpRemote implements OneLotusRemote {
  HttpRemote(this.api);

  final ApiClient api;

  /// Kursor halaman berikutnya per (kata kunci, filter) — layar memakai nomor halaman.
  final _cursors = <String, String?>{};

  @override
  Future<List<Session>> sessions({
    required String branchId,
    required DateTime from,
    required DateTime to,
    String? therapistId,
  }) async {
    final out = <Session>[];
    String? cursor;
    // Server membulatkan ke tanggal WIB; `to` di sini eksklusif → hari terakhir = to - 1 hari.
    final last = to.subtract(const Duration(days: 1));
    do {
      final page = await api.getPage('/v1/sessions', V1.session, query: {
        'branch_id': branchId,
        'from': formatDay(from),
        'to': formatDay(last.isBefore(from) ? from : last),
        'therapist_id': therapistId,
        'cursor': cursor,
      });
      out.addAll(page.items);
      cursor = page.hasMore ? page.nextCursor : null;
    } while (cursor != null);
    return out;
  }

  @override
  Future<Page<Patient>> searchPatients({
    required String query,
    required int page,
    required bool mineOnly,
  }) async {
    // Terapis otomatis hanya melihat pasiennya sendiri (server); [mineOnly] tidak perlu dikirim.
    final key = query;
    if (page == 1) _cursors.remove(key);
    if (page > 1 && _cursors[key] == null) {
      return Page(items: const [], page: page, hasMore: false);
    }
    final res = await api.getPage('/v1/patients', V1.patientItem, query: {
      'q': query,
      'limit': Page.size,
      'cursor': page > 1 ? _cursors[key] : null,
    });
    _cursors[key] = res.hasMore ? res.nextCursor : null;
    return Page(items: res.items, page: page, hasMore: res.hasMore);
  }

  @override
  Future<Patient> patient(String id) async {
    final overview = await api.get('/v1/patients/$id/overview', asMap);
    return V1.patient(asMap(overview['patient']), overview: overview);
  }

  /// Rekam sesi: id lokal = id sesi (server menyimpan satu rekam per sesi).
  Future<SessionRecord?> _record(String sessionId, {String patientId = '', String therapistId = ''}) async {
    try {
      return await api.get(
        '/v1/sessions/$sessionId/record',
        (d) => V1.record(asMap(d), id: sessionId, patientId: patientId, therapistId: therapistId),
      );
    } on AppError catch (e) {
      if (e.type == ErrorCode.notFound) return null;
      rethrow;
    }
  }

  @override
  Future<SessionRecord?> recordForSession(String sessionId) async {
    final s = await api.get('/v1/sessions/$sessionId', (d) => V1.session(asMap(d)));
    return _record(sessionId, patientId: s.patientId, therapistId: s.therapistId);
  }

  @override
  Future<SessionRecord?> latestRecordForPatient(String patientId) async =>
      (await recordHistory(patientId, page: 1, limit: 5)).items.firstOrNull;

  @override
  Future<Page<SessionRecord>> recordHistory(
    String patientId, {
    required int page,
    int limit = Page.size,
  }) async {
    // Riwayat = sesi pasien yang punya rekam lengkap, terbaru dulu (API tidak punya daftar rekam per pasien).
    final key = 'records:$patientId';
    if (page == 1) _cursors.remove(key);
    if (page > 1 && _cursors[key] == null) return Page(items: const [], page: page, hasMore: false);
    final res = await api.getPage('/v1/patients/$patientId/sessions', V1.session, query: {
      'limit': limit,
      'cursor': page > 1 ? _cursors[key] : null,
    });
    _cursors[key] = res.hasMore ? res.nextCursor : null;
    final withRecord = [
      for (final s in res.items)
        if (s.isFinished || s.status == SessionStatus.running) s,
    ];
    final records = await Future.wait([
      for (final s in withRecord) _record(s.id, patientId: patientId, therapistId: s.therapistId),
    ]);
    return Page(items: records.nonNulls.toList(), page: page, hasMore: res.hasMore);
  }

  @override
  Future<List<LegacyRecord>> legacyRecords(String patientId) => api.get(
    '/v1/patients/$patientId/legacy-records',
    (d) => parseList(d, V1.legacy),
  );

  @override
  Future<List<Service>> services({required String branchId}) async {
    final list = await api.get('/v1/services', (d) => parseList(d, (m) => m));
    return [
      for (final m in list)
        if ((m['is_active'] as bool? ?? true) &&
            ((m['branch_ids'] as List?)?.map((e) => e.toString()).contains(branchId) ?? true))
          Service.fromJson(m),
    ];
  }

  /// Tagihan (fase 2 backend). Sampai modul tagihan ada: null.
  @override
  Future<Invoice?> invoiceForSession(String sessionId) async {
    try {
      final page = await api.getPage('/v1/invoices', Invoice.fromJson, query: {'session_id': sessionId});
      return page.items.firstOrNull;
    } on AppError catch (e) {
      if (e.type == ErrorCode.notFound || e.apiCode == 'not_implemented') return null;
      rethrow;
    }
  }
}

/// Pengirim outbox ke API v1. Kunci item outbox dipakai sebagai `Idempotency-Key` (§9.2).
class ApiOutboxSender implements OutboxSender {
  ApiOutboxSender(this.api);

  final ApiClient api;

  @override
  Future<SendOutcome> send(OutboxItem item) async {
    final idem = {'Idempotency-Key': item.id};
    try {
      switch (item.kind) {
        case OutboxKinds.sessionRecordUpsert:
          final local = SessionRecord.fromJson(item.payload);
          final saved = await api.put(
            '/v1/sessions/${local.sessionId}/record',
            V1.recordInput(local),
            asMap,
            headers: {...idem, if (item.baseVersion > 0) 'If-Match': '${item.baseVersion}'},
          );
          final rec = V1.record(saved, id: local.id, patientId: local.patientId, therapistId: local.therapistId);
          return SendOk(serverVersion: rec.version, response: rec.toJson());
        case OutboxKinds.sessionStatus:
          final status = SessionStatus.fromApi(item.payload['status'] as String?);
          final action = V1.transitionFor(status);
          if (action == null) return const SendError(AppError(ErrorCode.validation));
          final saved = await api.post(
            '/v1/sessions/${item.entityId}/transitions',
            {'action': action, 'reason': item.payload['reason'], 'at': item.payload['at']},
            asMap,
            headers: idem,
          );
          return SendOk(response: V1.session(saved).toJson());
        case OutboxKinds.rescheduleRequest:
          final reason = [
            item.payload['reason'],
            if (item.payload['proposal'] != null) 'Usul: ${item.payload['proposal']}',
          ].join(' · ');
          await api.post(
            '/v1/sessions/${item.payload['session_id']}/reschedule-requests',
            {'reason': reason},
            (_) {},
            headers: idem,
          );
          return const SendOk();
        default:
          return const SendError(AppError(ErrorCode.unknown));
      }
    } on ConflictError catch (c) {
      // Versi server dikembalikan dalam bentuk model aplikasi agar ST-09 bisa membandingkan.
      final local = item.kind == OutboxKinds.sessionRecordUpsert ? SessionRecord.fromJson(item.payload) : null;
      final server = local == null || c.server.isEmpty
          ? c.server
          : V1.record(c.server, id: local.id, patientId: local.patientId, therapistId: local.therapistId).toJson();
      return SendConflict(serverPayload: server, serverVersion: c.serverVersion);
    } on AppError catch (e) {
      return SendError(e);
    }
  }
}
