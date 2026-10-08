import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

enum OutboxStatus {
  /// Menunggu dikirim (atau menunggu jadwal coba ulang).
  pending,
  sending,

  /// Ditolak server dengan error yang tidak bisa dicoba ulang otomatis (mis. 422/403).
  failed,

  /// Versi server lebih baru — terapis harus memilih versi (§8.4, ST-09).
  conflict,
}

/// Jalur kirim: data teks tidak menunggu unggahan lampiran (§8.5).
enum OutboxLane { data, upload }

class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.kind,
    required this.entityId,
    required this.payload,
    required this.createdAt,
    required this.nextAttemptAt,
    this.lane = OutboxLane.data,
    this.baseVersion = 0,
    this.status = OutboxStatus.pending,
    this.attempts = 0,
    this.lastError,
    this.lastErrorRef,
    this.serverPayload,
    this.serverVersion,
  });

  final String id;

  /// Jenis operasi, mis. `session_record.upsert`, `session.status`.
  final String kind;
  final OutboxLane lane;
  final String entityId;
  final Map<String, dynamic> payload;

  /// Versi server yang menjadi dasar perubahan ini (deteksi konflik).
  final int baseVersion;
  final OutboxStatus status;
  final int attempts;
  final DateTime createdAt;
  final DateTime nextAttemptAt;

  /// Kode error terakhir (`AppError.code`) & kode referensi server.
  final String? lastError;
  final String? lastErrorRef;

  /// Isi versi server saat konflik — disimpan agar kedua versi bisa dibandingkan.
  final Map<String, dynamic>? serverPayload;
  final int? serverVersion;

  OutboxItem copyWith({
    Map<String, dynamic>? payload,
    int? baseVersion,
    OutboxStatus? status,
    int? attempts,
    DateTime? nextAttemptAt,
    String? lastError,
    String? lastErrorRef,
    Map<String, dynamic>? serverPayload,
    int? serverVersion,
    bool clearError = false,
    bool clearServer = false,
  }) => OutboxItem(
    id: id,
    kind: kind,
    lane: lane,
    entityId: entityId,
    payload: payload ?? this.payload,
    baseVersion: baseVersion ?? this.baseVersion,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    createdAt: createdAt,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    lastError: clearError ? null : (lastError ?? this.lastError),
    lastErrorRef: clearError ? null : (lastErrorRef ?? this.lastErrorRef),
    serverPayload: clearServer ? null : (serverPayload ?? this.serverPayload),
    serverVersion: clearServer ? null : (serverVersion ?? this.serverVersion),
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'kind': kind,
    'lane': lane.name,
    'entity_id': entityId,
    'payload': jsonEncode(payload),
    'base_version': baseVersion,
    'status': status.name,
    'attempts': attempts,
    'created_at': createdAt.millisecondsSinceEpoch,
    'next_attempt_at': nextAttemptAt.millisecondsSinceEpoch,
    'last_error': lastError,
    'last_error_ref': lastErrorRef,
    'server_payload': serverPayload == null ? null : jsonEncode(serverPayload),
    'server_version': serverVersion,
  };

  factory OutboxItem.fromRow(Map<String, Object?> r) => OutboxItem(
    id: r['id']! as String,
    kind: r['kind']! as String,
    lane: OutboxLane.values.byName(r['lane']! as String),
    entityId: r['entity_id']! as String,
    payload: (jsonDecode(r['payload']! as String) as Map)
        .cast<String, dynamic>(),
    baseVersion: r['base_version']! as int,
    status: OutboxStatus.values.byName(r['status']! as String),
    attempts: r['attempts']! as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
    nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(
      r['next_attempt_at']! as int,
    ),
    lastError: r['last_error'] as String?,
    lastErrorRef: r['last_error_ref'] as String?,
    serverPayload: r['server_payload'] == null
        ? null
        : (jsonDecode(r['server_payload']! as String) as Map)
              .cast<String, dynamic>(),
    serverVersion: r['server_version'] as int?,
  );
}

/// ID acak 128-bit (format UUID v4) — dipakai untuk entitas yang dibuat offline.
String newId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int from, int to) => b
      .sublist(from, to)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
}

abstract interface class OutboxStore {
  Future<void> put(OutboxItem item);
  Future<OutboxItem?> byId(String id);

  /// Item pending untuk entitas & jenis yang sama (untuk penggabungan perubahan).
  Future<OutboxItem?> pendingFor(String kind, String entityId);
  Future<void> delete(String id);

  /// Item pending yang sudah waktunya dikirim: jalur data dulu, lalu urut waktu dibuat.
  Future<List<OutboxItem>> due(DateTime now);
  Future<List<OutboxItem>> all();

  /// Saat aplikasi mulai: item yang tertinggal di status `sending` dikembalikan ke `pending`.
  Future<void> resetSending();
}

class SqfliteOutboxStore implements OutboxStore {
  SqfliteOutboxStore(this.db);

  final Database db;

  @override
  Future<void> put(OutboxItem item) => db.insert(
    'outbox',
    item.toRow(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  @override
  Future<OutboxItem?> byId(String id) async {
    final rows = await db.query(
      'outbox',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : OutboxItem.fromRow(rows.first);
  }

  @override
  Future<OutboxItem?> pendingFor(String kind, String entityId) async {
    final rows = await db.query(
      'outbox',
      where: 'kind = ? AND entity_id = ? AND status = ?',
      whereArgs: [kind, entityId, OutboxStatus.pending.name],
      limit: 1,
    );
    return rows.isEmpty ? null : OutboxItem.fromRow(rows.first);
  }

  @override
  Future<void> delete(String id) =>
      db.delete('outbox', where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<OutboxItem>> due(DateTime now) async {
    final rows = await db.query(
      'outbox',
      where: 'status = ? AND next_attempt_at <= ?',
      whereArgs: [OutboxStatus.pending.name, now.millisecondsSinceEpoch],
      orderBy: "CASE lane WHEN 'data' THEN 0 ELSE 1 END, created_at",
    );
    return [for (final r in rows) OutboxItem.fromRow(r)];
  }

  @override
  Future<List<OutboxItem>> all() async => [
    for (final r in await db.query('outbox', orderBy: 'created_at'))
      OutboxItem.fromRow(r),
  ];

  @override
  Future<void> resetSending() => db.update(
    'outbox',
    {'status': OutboxStatus.pending.name},
    where: 'status = ?',
    whereArgs: [OutboxStatus.sending.name],
  );
}

class MemoryOutboxStore implements OutboxStore {
  final _items = <String, OutboxItem>{};

  @override
  Future<void> put(OutboxItem item) async => _items[item.id] = item;

  @override
  Future<OutboxItem?> byId(String id) async => _items[id];

  @override
  Future<OutboxItem?> pendingFor(String kind, String entityId) async => _items
      .values
      .where(
        (i) =>
            i.kind == kind &&
            i.entityId == entityId &&
            i.status == OutboxStatus.pending,
      )
      .firstOrNull;

  @override
  Future<void> delete(String id) async => _items.remove(id);

  @override
  Future<List<OutboxItem>> due(DateTime now) async {
    final list =
        _items.values
            .where(
              (i) =>
                  i.status == OutboxStatus.pending &&
                  !i.nextAttemptAt.isAfter(now),
            )
            .toList()
          ..sort((a, b) {
            final lane = a.lane.index.compareTo(b.lane.index);
            return lane != 0 ? lane : a.createdAt.compareTo(b.createdAt);
          });
    return list;
  }

  @override
  Future<List<OutboxItem>> all() async =>
      _items.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<void> resetSending() async {
    for (final e in _items.entries.toList()) {
      if (e.value.status == OutboxStatus.sending) {
        _items[e.key] = e.value.copyWith(status: OutboxStatus.pending);
      }
    }
  }
}
