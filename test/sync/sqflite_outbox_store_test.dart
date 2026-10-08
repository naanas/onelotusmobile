import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/local/kv_store.dart';
import 'package:onelotus_staff/data/local/local_db.dart';
import 'package:onelotus_staff/data/sync/outbox.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDb local;
  late SqfliteOutboxStore store;
  final t0 = DateTime(2026, 10, 6, 9);

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    local = await LocalDb.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    store = SqfliteOutboxStore(local.db);
  });
  tearDown(() => local.db.close());

  OutboxItem item(
    String id, {
    DateTime? created,
    DateTime? next,
    OutboxLane lane = OutboxLane.data,
    OutboxStatus status = OutboxStatus.pending,
  }) => OutboxItem(
    id: id,
    kind: 'session_record.upsert',
    lane: lane,
    entityId: 'e-$id',
    payload: {
      'id': id,
      'treated_areas': ['lower-back:left'],
    },
    createdAt: created ?? t0,
    nextAttemptAt: next ?? t0,
    status: status,
  );

  test('simpan & baca kembali utuh (termasuk JSON & versi server)', () async {
    await store.put(
      item(
        'a',
      ).copyWith(serverPayload: {'v': 2}, serverVersion: 2, baseVersion: 1),
    );
    final back = await store.byId('a');
    expect(back!.payload['treated_areas'], ['lower-back:left']);
    expect(back.serverPayload, {'v': 2});
    expect(back.baseVersion, 1);
  });

  test(
    'due: hanya pending yang sudah waktunya, data dulu lalu urut waktu',
    () async {
      await store.put(item('upload', lane: OutboxLane.upload, created: t0));
      await store.put(
        item('late', created: t0.add(const Duration(minutes: 2))),
      );
      await store.put(
        item('early', created: t0.add(const Duration(minutes: 1))),
      );
      await store.put(item('future', next: t0.add(const Duration(hours: 1))));
      await store.put(item('failed', status: OutboxStatus.failed));
      final due = await store.due(t0.add(const Duration(minutes: 5)));
      expect(due.map((i) => i.id), ['early', 'late', 'upload']);
    },
  );

  test('pendingFor & resetSending', () async {
    await store.put(item('a', status: OutboxStatus.sending));
    expect(await store.pendingFor('session_record.upsert', 'e-a'), isNull);
    await store.resetSending();
    expect((await store.pendingFor('session_record.upsert', 'e-a'))!.id, 'a');
  });

  test('KvStore draf: simpan, ganti, hapus, daftar kunci', () async {
    final drafts = SqfliteKvStore(local.db, 'drafts');
    await drafts.put('record:s1', {'complaint': 'nyeri'});
    await drafts.put('record:s1', {'complaint': 'nyeri pinggang'});
    await drafts.put('other', 1);
    expect((await drafts.get('record:s1'))!.json, {
      'complaint': 'nyeri pinggang',
    });
    expect(await drafts.keys(prefix: 'record:'), ['record:s1']);
    await drafts.delete('record:s1');
    expect(await drafts.get('record:s1'), isNull);
  });
}
