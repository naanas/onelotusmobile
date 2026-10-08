import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/sync/outbox.dart';
import 'package:onelotus_staff/data/sync/sync_engine.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

/// Pengirim dengan hasil yang diatur per panggilan.
class ScriptedSender implements OutboxSender {
  final outcomes = <SendOutcome>[];

  /// Selama true, semua kiriman gagal karena tidak ada sinyal.
  bool offline = false;
  final sent = <OutboxItem>[];
  Completer<void>? gate;

  @override
  Future<SendOutcome> send(OutboxItem item) async {
    sent.add(item);
    if (gate != null) await gate!.future;
    if (offline) return const SendError(AppError(ErrorCode.networkOffline));
    return outcomes.isEmpty
        ? const SendOk(serverVersion: 1)
        : outcomes.removeAt(0);
  }
}

void main() {
  late MemoryOutboxStore store;
  late ScriptedSender sender;
  late DateTime now;
  late SyncEngine engine;

  setUp(() {
    store = MemoryOutboxStore();
    sender = ScriptedSender();
    now = DateTime(2026, 10, 6, 9);
    engine = SyncEngine(
      store: store,
      sender: sender,
      clock: () => now,
      autoSchedule: false,
    );
  });
  tearDown(() => engine.dispose());

  Future<OutboxItem> enqueue(
    String entity, [
    Map<String, dynamic>? payload,
    int base = 0,
  ]) async {
    final item = await engine.enqueue(
      kind: 'k',
      entityId: entity,
      payload: payload ?? {'v': 1},
      baseVersion: base,
    );
    await engine.flush();
    return item;
  }

  test('berhasil terkirim → keluar dari outbox & diumumkan', () async {
    final events = <(OutboxItem, SendOk)>[];
    engine.sent.listen(events.add);
    await enqueue('a');
    expect(await store.all(), isEmpty);
    expect(sender.sent, hasLength(1));
    expect(engine.snapshot.value.unsynced, 0);
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
  });

  test('offline: tetap tersimpan, coba ulang dengan backoff', () async {
    sender.offline = true;
    final t0 = now;
    await enqueue('a');
    now = now.add(const Duration(seconds: 1));
    await enqueue('b');

    final items = await store.all();
    expect(items, hasLength(2));
    final a = items.firstWhere((i) => i.entityId == 'a');
    expect(a.status, OutboxStatus.pending);
    expect(a.attempts, 1);
    expect(a.nextAttemptAt, t0.add(const Duration(seconds: 5)));
    expect(a.lastError, 'network_offline');
    expect(engine.snapshot.value.offline, isTrue);
    expect(engine.snapshot.value.pending, 2);

    // Belum waktunya: tidak dicoba lagi (hemat baterai & jaringan).
    sender.sent.clear();
    await engine.flush();
    expect(sender.sent, isEmpty);

    // Sinyal kembali & jeda lewat: semua terkirim berurutan.
    sender.offline = false;
    now = now.add(const Duration(seconds: 10));
    await engine.flush();
    expect(sender.sent.map((i) => i.entityId), ['a', 'b']);
    expect(await store.all(), isEmpty);
    expect(engine.snapshot.value.offline, isFalse);
  });

  test('backoff 5 dtk, 10, 20 … maks 5 menit', () {
    expect(SyncEngine.backoff(1), const Duration(seconds: 5));
    expect(SyncEngine.backoff(2), const Duration(seconds: 10));
    expect(SyncEngine.backoff(4), const Duration(seconds: 40));
    expect(SyncEngine.backoff(20), const Duration(minutes: 5));
  });

  test(
    'perubahan beruntun untuk entitas yang sama digabung (yang dikirim versi terakhir)',
    () async {
      engine.setPaused(true);
      await engine.enqueue(kind: 'k', entityId: 'a', payload: {'v': 1});
      await engine.enqueue(kind: 'k', entityId: 'a', payload: {'v': 2});
      expect(await store.all(), hasLength(1));
      engine.setPaused(false);
      await engine.flush();
      expect(sender.sent.single.payload, {'v': 2});
    },
  );

  test(
    'perubahan saat sedang mengirim memakai versi server baru sebagai dasar',
    () async {
      sender.gate = Completer();
      sender.outcomes.add(const SendOk(serverVersion: 7));
      await engine.enqueue(
        kind: 'k',
        entityId: 'a',
        payload: {'v': 1},
        baseVersion: 6,
      );
      final first = engine.flush();
      await Future<void>.delayed(Duration.zero);
      expect((await store.all()).single.status, OutboxStatus.sending);

      await engine.enqueue(
        kind: 'k',
        entityId: 'a',
        payload: {'v': 2},
        baseVersion: 6,
      );
      sender.gate!.complete();
      sender.gate = null;
      await first;
      await engine.flush();
      expect(sender.sent.map((i) => i.payload['v']), [1, 2]);
      expect(sender.sent.last.baseVersion, 7);
      expect(await store.all(), isEmpty);
    },
  );

  test(
    'error yang tidak bisa diulang (422) → gagal; bisa dicoba lagi atau dibuang',
    () async {
      sender.outcomes.add(
        const SendError(AppError(ErrorCode.validation, refId: 'OL-1')),
      );
      final item = await enqueue('a');
      var stored = await store.byId(item.id);
      expect(stored!.status, OutboxStatus.failed);
      expect(stored.lastErrorRef, 'OL-1');
      expect(engine.snapshot.value.failed, 1);

      await engine.retry(item.id);
      expect(await store.byId(item.id), isNull);

      sender.outcomes.add(const SendError(AppError(ErrorCode.forbidden)));
      final other = await enqueue('b');
      await engine.discard(other.id);
      expect(await store.all(), isEmpty);
    },
  );

  test('5xx dicoba ulang otomatis, bukan dianggap gagal', () async {
    sender.outcomes.add(const SendError(AppError(ErrorCode.serverError)));
    final item = await enqueue('a');
    final stored = await store.byId(item.id);
    expect(stored!.status, OutboxStatus.pending);
    expect(engine.snapshot.value.offline, isFalse);
  });

  test(
    'konflik: simpan versi server; pilih versi HP → kirim ulang dengan versi server',
    () async {
      sender.outcomes.add(
        const SendConflict(serverPayload: {'v': 'server'}, serverVersion: 4),
      );
      final item = await enqueue('a', {'v': 'hp'}, 2);
      final c = await store.byId(item.id);
      expect(c!.status, OutboxStatus.conflict);
      expect(c.serverPayload, {'v': 'server'});
      expect(engine.snapshot.value.conflicts, 1);

      await engine.resolveKeepMine(item.id);
      expect(sender.sent.last.baseVersion, 4);
      expect(sender.sent.last.payload, {'v': 'hp'});
      expect(await store.all(), isEmpty);
    },
  );

  test(
    'konflik: pilih versi server → perubahan HP dibuang, isi server dikembalikan',
    () async {
      sender.outcomes.add(
        const SendConflict(serverPayload: {'v': 'server'}, serverVersion: 4),
      );
      final item = await enqueue('a', {'v': 'hp'});
      expect(await engine.resolveKeepServer(item.id), {'v': 'server'});
      expect(await store.all(), isEmpty);
    },
  );

  test('jalur data dikirim sebelum unggahan lampiran', () async {
    engine.setPaused(true);
    await engine.enqueue(
      kind: 'upload',
      entityId: 'foto',
      payload: {},
      lane: OutboxLane.upload,
    );
    now = now.add(const Duration(seconds: 1));
    await engine.enqueue(kind: 'k', entityId: 'teks', payload: {});
    engine.setPaused(false);
    await engine.flush();
    expect(sender.sent.map((i) => i.entityId), ['teks', 'foto']);
  });

  test(
    'item yang tertinggal "sending" (aplikasi tertutup) dikirim ulang saat mulai',
    () async {
      await store.put(
        OutboxItem(
          id: 'x',
          kind: 'k',
          entityId: 'a',
          payload: const {},
          createdAt: now,
          nextAttemptAt: now,
          status: OutboxStatus.sending,
        ),
      );
      await engine.start();
      await engine.flush();
      expect(sender.sent.single.id, 'x');
    },
  );

  test('dijeda saat belum login: tidak mengirim, data tetap', () async {
    engine.setPaused(true);
    await enqueue('a');
    expect(sender.sent, isEmpty);
    expect(engine.snapshot.value.pending, 1);
  });

  test('koneksi kembali → langsung kirim tanpa menunggu jeda', () async {
    sender.offline = true;
    await enqueue('a');
    expect(engine.snapshot.value.offline, isTrue);
    sender.offline = false;
    engine.setOffline(false);
    await Future<void>.delayed(Duration.zero);
    await engine.flush();
    expect(await store.all(), isEmpty);
  });
}
