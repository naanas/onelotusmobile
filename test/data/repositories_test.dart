import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/local/kv_store.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/data/remote/mock_backend.dart';
import 'package:onelotus_staff/data/repositories/repository_impl.dart';
import 'package:onelotus_staff/data/sync/outbox.dart';
import 'package:onelotus_staff/data/sync/sync_engine.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

void main() {
  final today = DateTime(2026, 10, 6);
  late MockBackend backend;
  late SyncEngine engine;
  late MemoryKvStore cache;
  late MemoryKvStore drafts;
  late ScheduleRepositoryImpl schedule;
  late SessionRecordRepositoryImpl records;
  late PatientRepositoryImpl patients;

  setUp(() {
    backend = MockBackend(today: today, latency: Duration.zero);
    engine = SyncEngine(
      store: MemoryOutboxStore(),
      sender: MockOutboxSender(backend),
      autoSchedule: false,
    );
    cache = MemoryKvStore();
    drafts = MemoryKvStore();
    final remote = MockRemote(backend, currentUserId: () => 'u1');
    schedule = ScheduleRepositoryImpl(
      remote: remote,
      cache: cache,
      engine: engine,
    );
    records = SessionRecordRepositoryImpl(
      remote: remote,
      cache: cache,
      drafts: drafts,
      engine: engine,
    );
    patients = PatientRepositoryImpl(remote: remote, cache: cache);
  });
  tearDown(() {
    records.dispose();
    engine.dispose();
  });

  test('jadwal hari ini terapis Dimas sesuai TR-01, urut jam', () async {
    final f = await schedule.sessionsForDay(
      branchId: 'pusat',
      day: today,
      therapistId: 'u1',
    );
    expect(f.stale, isFalse);
    expect(f.data.map((s) => s.patientName), [
      'Rina Setiawati',
      'Andi Pratama',
      'Budi Hartono',
      'Sari Wulandari',
    ]);
    expect(f.data[2].isHomeVisit, isTrue);
  });

  test('offline: jadwal dari cache, ditandai stale', () async {
    await schedule.sessionsForDay(
      branchId: 'pusat',
      day: today,
      therapistId: 'u1',
    );
    backend.offline = true;
    final f = await schedule.sessionsForDay(
      branchId: 'pusat',
      day: today,
      therapistId: 'u1',
    );
    expect(f.stale, isTrue);
    expect(f.data, hasLength(4));
  });

  test('offline tanpa cache → error network_offline', () async {
    backend.offline = true;
    expect(
      () => schedule.sessionsForDay(branchId: 'pusat', day: today),
      throwsA(
        isA<AppError>().having((e) => e.type, 'type', ErrorCode.networkOffline),
      ),
    );
  });

  test(
    'ubah status offline: langsung terlihat, terkirim saat online',
    () async {
      final s = (await schedule.sessionsForDay(
        branchId: 'pusat',
        day: today,
        therapistId: 'u1',
      )).data.firstWhere((s) => s.patientName == 'Sari Wulandari');
      backend.offline = true;
      final updated = await schedule.updateStatus(s, SessionStatus.running);
      expect(updated.status, SessionStatus.running);
      await engine.flush();
      expect(engine.snapshot.value.pending, 1);

      final again = await schedule.sessionsForDay(
        branchId: 'pusat',
        day: today,
        therapistId: 'u1',
      );
      expect(
        again.data.firstWhere((x) => x.id == s.id).status,
        SessionStatus.running,
      );

      backend.offline = false;
      await engine.retryNow();
      expect(engine.snapshot.value.pending, 0);
      expect(backend.sessions[s.id]!.status, SessionStatus.running);
    },
  );

  test('prefill rekam sesi dari sesi lalu (§5.2)', () async {
    final last = await records.latestForPatient('p0412');
    final fresh = const SessionRecord(
      id: 'new',
      sessionId: 's2',
      patientId: 'p0412',
      therapistId: 'u1',
    ).prefilledFrom(last!);
    expect(fresh.treatedAreas, contains('lower-back:left'));
    expect(fresh.treatments, ['Adjustment', 'Infrared']);
    expect(
      fresh.painBefore,
      7,
      reason: 'nyeri sebelum = nyeri sesudah sesi lalu',
    );
    expect(fresh.painAfter, isNull);
  });

  test('draf autosave → simpan offline → terbaca lokal → tersinkron', () async {
    const r = SessionRecord(
      id: 'r-new',
      sessionId: 's2',
      patientId: 'p0412',
      therapistId: 'u1',
      treatedAreas: ['lower-back:left'],
      treatments: ['Adjustment'],
      painBefore: 7,
      painAfter: 3,
    );
    await records.saveDraft(r);
    expect((await records.loadDraft('s2'))!.painAfter, 3);

    backend.offline = true;
    await records.submit(r);
    await engine.flush();
    expect(
      await records.loadDraft('s2'),
      isNull,
      reason: 'draf dihapus setelah disimpan',
    );
    expect(
      (await records.forSession('s2'))!.painAfter,
      3,
      reason: 'versi lokal tetap terbaca offline',
    );
    expect((await records.latestForPatient('p0412'))!.id, 'r-new');

    backend.offline = false;
    await engine.retryNow();
    expect(backend.records['r-new']!.version, 1);
    expect(engine.snapshot.value.unsynced, 0);
  });

  test('konflik versi lewat MockOutboxSender', () async {
    final server = backend.records['r-s8']!;
    // Perangkat lain sudah menyimpan versi 2.
    backend.records['r-s8'] = server.copyWith(
      version: 2,
      conclusion: 'diubah di HP lain',
    );
    await records.submit(server.copyWith(conclusion: 'diubah di HP ini'));
    await engine.flush();
    final item = engine.snapshot.value.items.single;
    expect(item.status, OutboxStatus.conflict);
    expect(item.serverPayload!['conclusion'], 'diubah di HP lain');

    await engine.resolveKeepMine(item.id);
    expect(backend.records['r-s8']!.conclusion, 'diubah di HP ini');
    expect(backend.records['r-s8']!.version, 3);
  });

  test('cari pasien: nama, nomor #, 4 digit HP, paging 20', () async {
    expect((await patients.search(query: 'andi')).items.single.number, 412);
    expect(
      (await patients.search(query: '#0412')).items.single.name,
      'Andi Pratama',
    );
    expect(
      (await patients.search(query: '0387')).items.single.name,
      'Rina Setiawati',
    );
    final p1 = await patients.search();
    expect(p1.items, hasLength(20));
    expect(p1.hasMore, isTrue);
    final p2 = await patients.search(page: 2);
    expect(p2.hasMore, isFalse);
    final mine = await patients.search(mineOnly: true);
    expect(
      mine.items.map((p) => p.name),
      containsAll(['Andi Pratama', 'Budi Hartono']),
    );
    expect(mine.items.map((p) => p.name), isNot(contains('Dewi Lestari')));
  });

  test('JSON bolak-balik tidak kehilangan data', () {
    final s = backend.sessions['s4']!;
    final s2 = Session.fromJson(s.toJson());
    expect(s2.homeVisit!.distanceKm, 4.2);
    expect(s2.startAt, s.startAt);
    expect(s2.status, SessionStatus.scheduled);

    final p = backend.patients['p0387']!;
    final p2 = Patient.fromJson(p.toJson());
    expect(p2.activePackage!.almostEmpty, isTrue);
    expect(p2.birthDate, DateTime(1990, 3, 12));
    expect(p2.ageOn(today), 36);

    final r = backend.records['r-s8']!;
    expect(SessionRecord.fromJson(r.toJson()).toJson(), r.toJson());

    final inv = backend.invoices['s2']!;
    expect(inv.subtotal, 500000);
    expect(inv.grandTotal, 450000);
    expect(Invoice.fromJson(inv.toJson()).grandTotal, 450000);
  });
}
