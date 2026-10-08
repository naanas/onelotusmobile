import 'dart:async';

import '../../ui/feedback/app_error.dart';
import '../local/kv_store.dart';
import '../models/json.dart';
import '../models/models.dart';
import '../remote/remote.dart';
import '../sync/outbox.dart';
import '../sync/sync_engine.dart';
import 'repositories.dart';

/// Ambil dari server lalu simpan ke cache; bila tidak ada sinyal, pakai cache (§8).
Future<Fetched<T>> cachedFetch<T>({
  required KvStore cache,
  required String key,
  required Future<T> Function() fetch,
  required Object? Function(T) encode,
  required T Function(Object?) decode,
}) async {
  try {
    final value = await fetch();
    await cache.put(key, encode(value));
    return Fetched(value, fetchedAt: DateTime.now());
  } on AppError catch (e) {
    if (e.type != ErrorCode.networkOffline &&
        e.type != ErrorCode.networkTimeout) {
      rethrow;
    }
    final hit = await cache.get(key);
    if (hit == null) rethrow;
    return Fetched(decode(hit.json), stale: true, fetchedAt: hit.at);
  }
}

List<Object?> _encodeList<T>(List<T> l, Map<String, dynamic> Function(T) f) => [
  for (final e in l) f(e),
];

List<T> _decodeList<T>(Object? j, T Function(Map<String, dynamic>) f) => [
  for (final e in (j as List)) f((e as Map).cast<String, dynamic>()),
];

String _day(DateTime d) => formatDay(d)!;

class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl({
    required this.remote,
    required this.cache,
    required this.engine,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final OneLotusRemote remote;
  final KvStore cache;
  final SyncEngine engine;
  final DateTime Function() _now;

  @override
  Future<Fetched<List<Session>>> sessionsForDay({
    required String branchId,
    required DateTime day,
    String? therapistId,
  }) {
    final from = DateTime(day.year, day.month, day.day);
    return sessionsForRange(
      branchId: branchId,
      from: from,
      to: from.add(const Duration(days: 1)),
      therapistId: therapistId,
    );
  }

  @override
  Future<Fetched<List<Session>>> sessionsForRange({
    required String branchId,
    required DateTime from,
    required DateTime to,
    String? therapistId,
  }) async {
    final fetched = await cachedFetch<List<Session>>(
      cache: cache,
      key: 'sessions:$branchId:${therapistId ?? '*'}:${_day(from)}:${_day(to)}',
      fetch: () => remote.sessions(
        branchId: branchId,
        from: from,
        to: to,
        therapistId: therapistId,
      ),
      encode: (l) => _encodeList(l, (s) => s.toJson()),
      decode: (j) => _decodeList(j, Session.fromJson),
    );
    // Perubahan status yang belum terkirim tetap terlihat (offline).
    final pending = {
      for (final i in await engine.store.all())
        if (i.kind == OutboxKinds.sessionStatus) i.entityId: i.payload,
    };
    if (pending.isEmpty) return fetched;
    return Fetched(
      [
        for (final s in fetched.data)
          pending.containsKey(s.id) ? _applyStatus(s, pending[s.id]!) : s,
      ],
      stale: fetched.stale,
      fetchedAt: fetched.fetchedAt,
    );
  }

  static Session _applyStatus(Session s, Map<String, dynamic> p) {
    final status = SessionStatus.fromApi(p['status'] as String?);
    final at = parseDate(p['at']);
    return s.copyWith(
      status: status,
      arrivedAt: status == SessionStatus.arrived ? at : null,
      startedAt: status == SessionStatus.running ? at : null,
      endedAt: status == SessionStatus.done ? at : null,
    );
  }

  @override
  Future<Session> updateStatus(
    Session session,
    SessionStatus status, {
    String? reason,
  }) async {
    final payload = {
      'status': status.api,
      'at': formatDate(_now()),
      'reason': ?reason,
    };
    await engine.enqueue(
      kind: OutboxKinds.sessionStatus,
      entityId: session.id,
      payload: payload,
    );
    return _applyStatus(session, payload);
  }

  @override
  Future<void> requestReschedule(
    Session session, {
    required String reason,
    String? proposal,
  }) => engine.enqueue(
    kind: OutboxKinds.rescheduleRequest,
    entityId: newId(),
    payload: {
      'session_id': session.id,
      'reason': reason,
      'proposal': ?proposal,
      'at': formatDate(_now()),
    },
  );
}

class PatientRepositoryImpl implements PatientRepository {
  PatientRepositoryImpl({required this.remote, required this.cache});

  final OneLotusRemote remote;
  final KvStore cache;

  @override
  Future<Page<Patient>> search({
    String query = '',
    int page = 1,
    bool mineOnly = false,
  }) async {
    // Hanya halaman pertama daftar tanpa kata kunci yang di-cache (cukup untuk dibuka offline).
    if (query.isNotEmpty || page > 1) {
      return remote.searchPatients(
        query: query,
        page: page,
        mineOnly: mineOnly,
      );
    }
    final f = await cachedFetch<Page<Patient>>(
      cache: cache,
      key: 'patients:first:${mineOnly ? 'mine' : 'all'}',
      fetch: () =>
          remote.searchPatients(query: '', page: 1, mineOnly: mineOnly),
      encode: (p) => {
        'items': _encodeList(p.items, (x) => x.toJson()),
        'has_more': p.hasMore,
      },
      decode: (j) {
        final m = (j as Map).cast<String, dynamic>();
        return Page(
          items: _decodeList(m['items'], Patient.fromJson),
          page: 1,
          hasMore: m['has_more'] as bool,
        );
      },
    );
    return f.data;
  }

  @override
  Future<Fetched<Patient>> byId(String id) => cachedFetch(
    cache: cache,
    key: 'patient:$id',
    fetch: () => remote.patient(id),
    encode: (p) => p.toJson(),
    decode: (j) => Patient.fromJson((j as Map).cast<String, dynamic>()),
  );
}

class SessionRecordRepositoryImpl implements SessionRecordRepository {
  SessionRecordRepositoryImpl({
    required this.remote,
    required this.cache,
    required this.drafts,
    required this.engine,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    _sub = engine.sent.listen((e) {
      final (item, ok) = e;
      if (item.kind == OutboxKinds.sessionRecordUpsert && ok.response != null) {
        final saved = SessionRecord.fromJson(ok.response!);
        unawaited(
          cache.put('record:session:${saved.sessionId}', saved.toJson()),
        );
      }
    });
  }

  final OneLotusRemote remote;
  final KvStore cache;
  final KvStore drafts;
  final SyncEngine engine;
  final DateTime Function() _now;
  late final StreamSubscription<(OutboxItem, SendOk)> _sub;

  void dispose() => _sub.cancel();

  /// Rekam sesi yang sudah disimpan tapi belum sampai server.
  Future<List<SessionRecord>> _unsent() async => [
    for (final i in await engine.store.all())
      if (i.kind == OutboxKinds.sessionRecordUpsert)
        SessionRecord.fromJson(i.payload),
  ];

  @override
  Future<SessionRecord?> forSession(String sessionId) async {
    final local = (await _unsent())
        .where((r) => r.sessionId == sessionId)
        .lastOrNull;
    if (local != null) return local;
    try {
      final r = await remote.recordForSession(sessionId);
      if (r != null) await cache.put('record:session:$sessionId', r.toJson());
      return r;
    } on AppError catch (e) {
      if (e.type != ErrorCode.networkOffline &&
          e.type != ErrorCode.networkTimeout) {
        rethrow;
      }
      final hit = await cache.get('record:session:$sessionId');
      return hit == null
          ? null
          : SessionRecord.fromJson((hit.json! as Map).cast<String, dynamic>());
    }
  }

  @override
  Future<SessionRecord?> latestForPatient(String patientId) async {
    final local = (await _unsent())
        .where((r) => r.patientId == patientId)
        .toList();
    SessionRecord? remoteLatest;
    try {
      final f = await cachedFetch<SessionRecord?>(
        cache: cache,
        key: 'record:latest:$patientId',
        fetch: () => remote.latestRecordForPatient(patientId),
        encode: (r) => r?.toJson(),
        decode: (j) => j == null
            ? null
            : SessionRecord.fromJson((j as Map).cast<String, dynamic>()),
      );
      remoteLatest = f.data;
    } on AppError catch (e) {
      if (e.type != ErrorCode.networkOffline &&
          e.type != ErrorCode.networkTimeout) {
        rethrow;
      }
    }
    final all = [...local, ?remoteLatest]
      ..sort(
        (a, b) => (b.updatedAt ?? DateTime(1970)).compareTo(
          a.updatedAt ?? DateTime(1970),
        ),
      );
    return all.firstOrNull;
  }

  @override
  Future<Page<SessionRecord>> historyForPatient(
    String patientId, {
    int page = 1,
  }) => remote.recordHistory(patientId, page: page);

  @override
  Future<List<LegacyRecord>> legacyForPatient(String patientId) =>
      remote.legacyRecords(patientId);

  @override
  Future<SessionRecord?> loadDraft(String sessionId) async {
    final hit = await drafts.get('record:$sessionId');
    return hit == null
        ? null
        : SessionRecord.fromJson((hit.json! as Map).cast<String, dynamic>());
  }

  @override
  Future<void> saveDraft(SessionRecord record) =>
      drafts.put('record:${record.sessionId}', record.toJson());

  @override
  Future<void> deleteDraft(String sessionId) =>
      drafts.delete('record:$sessionId');

  @override
  Future<void> submit(SessionRecord record) async {
    final stamped = record.copyWith(updatedAt: _now());
    await engine.enqueue(
      kind: OutboxKinds.sessionRecordUpsert,
      entityId: record.id,
      payload: stamped.toJson(),
      baseVersion: record.version,
    );
    await deleteDraft(record.sessionId);
  }
}

class ServiceRepositoryImpl implements ServiceRepository {
  ServiceRepositoryImpl({required this.remote, required this.cache});

  final OneLotusRemote remote;
  final KvStore cache;

  @override
  Future<Fetched<List<Service>>> services({required String branchId}) =>
      cachedFetch(
        cache: cache,
        key: 'services:$branchId',
        fetch: () => remote.services(branchId: branchId),
        encode: (l) => _encodeList(l, (s) => s.toJson()),
        decode: (j) => _decodeList(j, Service.fromJson),
      );
}

class InvoiceRepositoryImpl implements InvoiceRepository {
  InvoiceRepositoryImpl({required this.remote});

  final OneLotusRemote remote;

  /// Tagihan selalu dari server (status pembayaran hanya sah dari server, §6.4.1).
  @override
  Future<Invoice?> forSession(String sessionId) =>
      remote.invoiceForSession(sessionId);
}
