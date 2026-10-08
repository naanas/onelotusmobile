import '../../ui/feedback/app_error.dart';
import '../api/api_client.dart';
import '../api/api_error_mapper.dart';
import '../models/json.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../sync/outbox.dart';
import '../sync/sync_engine.dart';
import 'remote.dart';

/// [OneLotusRemote] ke One Lotus API. Endpoint: docs/api-kontrak.md (usulan, disepakati di Fase 0).
class HttpRemote implements OneLotusRemote {
  HttpRemote(this.api);

  final ApiClient api;

  static Page<T> _page<T>(
    dynamic data,
    int page,
    T Function(Map<String, dynamic>) f,
  ) {
    // Laravel paginator: { data: [...], meta: { current_page, last_page } } — ApiClient sudah membuka `data`.
    final items = parseList(data, f);
    return Page(items: items, page: page, hasMore: items.length >= Page.size);
  }

  @override
  Future<List<Session>> sessions({
    required String branchId,
    required DateTime from,
    required DateTime to,
    String? therapistId,
  }) => api.get(
    '/v1/sessions',
    (d) => parseList(d, Session.fromJson),
    query: {
      'branch_id': branchId,
      'from': formatDate(from),
      'to': formatDate(to),
      'therapist_id': ?therapistId,
    },
  );

  @override
  Future<Page<Patient>> searchPatients({
    required String query,
    required int page,
    required bool mineOnly,
  }) => api.get(
    '/v1/patients',
    (d) => _page(d, page, Patient.fromJson),
    query: {
      'q': query,
      'page': page,
      'per_page': Page.size,
      if (mineOnly) 'scope': 'mine',
    },
  );

  @override
  Future<Patient> patient(String id) =>
      api.get('/v1/patients/$id', (d) => Patient.fromJson(asMap(d)));

  @override
  Future<SessionRecord?> recordForSession(String sessionId) async {
    try {
      return await api.get(
        '/v1/sessions/$sessionId/record',
        (d) => SessionRecord.fromJson(asMap(d)),
      );
    } on AppError catch (e) {
      if (e.type == ErrorCode.notFound) return null;
      rethrow;
    }
  }

  @override
  Future<SessionRecord?> latestRecordForPatient(String patientId) async =>
      (await recordHistory(patientId, page: 1)).items.firstOrNull;

  @override
  Future<Page<SessionRecord>> recordHistory(
    String patientId, {
    required int page,
  }) => api.get(
    '/v1/patients/$patientId/records',
    (d) => _page(d, page, SessionRecord.fromJson),
    query: {'page': page, 'per_page': Page.size},
  );

  @override
  Future<List<LegacyRecord>> legacyRecords(String patientId) => api.get(
    '/v1/patients/$patientId/legacy-records',
    (d) => parseList(d, LegacyRecord.fromJson),
  );

  @override
  Future<List<Service>> services({required String branchId}) => api.get(
    '/v1/services',
    (d) => parseList(d, Service.fromJson),
    query: {'branch_id': branchId},
  );

  @override
  Future<Invoice?> invoiceForSession(String sessionId) async {
    try {
      return await api.get(
        '/v1/sessions/$sessionId/invoice',
        (d) => Invoice.fromJson(asMap(d)),
      );
    } on AppError catch (e) {
      if (e.type == ErrorCode.notFound) return null;
      rethrow;
    }
  }
}

/// Pengirim outbox ke API. 409 `edit_conflict` membawa versi server di `server`.
class ApiOutboxSender implements OutboxSender {
  ApiOutboxSender(this.api);

  final ApiClient api;

  @override
  Future<SendOutcome> send(OutboxItem item) async {
    try {
      switch (item.kind) {
        case OutboxKinds.sessionRecordUpsert:
          final saved = await api.put('/v1/session-records/${item.entityId}', {
            ...item.payload,
            'base_version': item.baseVersion,
          }, asMap);
          return SendOk(
            serverVersion: parseInt(saved['version']),
            response: saved,
          );
        case OutboxKinds.sessionStatus:
          final saved = await api.patch(
            '/v1/sessions/${item.entityId}/status',
            item.payload,
            asMap,
          );
          return SendOk(response: saved);
        default:
          return const SendError(AppError(ErrorCode.unknown));
      }
    } on ConflictError catch (c) {
      return SendConflict(
        serverPayload: c.server,
        serverVersion: c.serverVersion,
      );
    } on AppError catch (e) {
      return SendError(e);
    }
  }
}
