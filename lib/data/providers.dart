import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import 'api/api_client.dart';
import 'auth/auth_controller.dart';
import 'local/kv_store.dart';
import 'local/local_db.dart';
import 'remote/http_remote.dart';
import 'remote/mock_backend.dart';
import 'remote/remote.dart';
import 'repositories/repositories.dart';
import 'repositories/repository_impl.dart';
import 'sync/outbox.dart';
import 'sync/sync_engine.dart';

/// Dibuka di `main()` lalu di-override (pembukaan database bersifat async).
final localDbProvider = Provider<LocalDb>(
  (ref) => throw UnimplementedError('localDbProvider harus di-override'),
);

final outboxStoreProvider = Provider<OutboxStore>(
  (ref) => SqfliteOutboxStore(ref.watch(localDbProvider).db),
);
final draftStoreProvider = Provider<KvStore>(
  (ref) => SqfliteKvStore(ref.watch(localDbProvider).db, 'drafts'),
);
final cacheStoreProvider = Provider<KvStore>(
  (ref) => SqfliteKvStore(ref.watch(localDbProvider).db, 'cache'),
);

// ── Sumber data: mock (API_URL kosong) atau One Lotus API ──────────────────

final mockBackendProvider = Provider<MockBackend>((ref) => MockBackend());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: AppConfig.apiUrl,
    token: () => ref.read(authProvider).token,
    onUnauthorized: () => ref.read(authProvider.notifier).expireSession(),
  ),
);

final remoteProvider = Provider<OneLotusRemote>(
  (ref) => AppConfig.useMock
      ? MockRemote(
          ref.watch(mockBackendProvider),
          currentUserId: () => ref.read(authProvider).user?.id,
        )
      : HttpRemote(ref.watch(apiClientProvider)),
);

final outboxSenderProvider = Provider<OutboxSender>(
  (ref) => AppConfig.useMock
      ? MockOutboxSender(ref.watch(mockBackendProvider))
      : ApiOutboxSender(ref.watch(apiClientProvider)),
);

/// Status koneksi perangkat. Override di tes.
final connectivityProvider = Provider<Stream<bool>>(
  (ref) => Connectivity().onConnectivityChanged.map(
    (r) => r.any((c) => c != ConnectivityResult.none),
  ),
);

// ── Outbox & status sinkron (§8) ───────────────────────────────────────────

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    store: ref.watch(outboxStoreProvider),
    sender: ref.watch(outboxSenderProvider),
  );

  // Kirim hanya saat ada token; data tetap tersimpan selama logout / sesi berakhir.
  void applyAuth(AuthState s) => engine.setPaused(s.token == null);
  applyAuth(ref.read(authProvider));
  ref.listen(authProvider, (_, s) => applyAuth(s));

  final sub = ref
      .watch(connectivityProvider)
      .listen((online) => engine.setOffline(!online));
  ref.onDispose(() {
    unawaited(sub.cancel());
    engine.dispose();
  });
  unawaited(engine.start());
  return engine;
});

final syncSnapshotProvider =
    NotifierProvider<SyncSnapshotNotifier, SyncSnapshot>(
      SyncSnapshotNotifier.new,
    );

class SyncSnapshotNotifier extends Notifier<SyncSnapshot> {
  @override
  SyncSnapshot build() {
    final engine = ref.watch(syncEngineProvider);
    void listener() => state = engine.snapshot.value;
    engine.snapshot.addListener(listener);
    ref.onDispose(() => engine.snapshot.removeListener(listener));
    return engine.snapshot.value;
  }
}

// ── Repository ─────────────────────────────────────────────────────────────

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepositoryImpl(
    remote: ref.watch(remoteProvider),
    cache: ref.watch(cacheStoreProvider),
    engine: ref.watch(syncEngineProvider),
  ),
);

final patientRepositoryProvider = Provider<PatientRepository>(
  (ref) => PatientRepositoryImpl(
    remote: ref.watch(remoteProvider),
    cache: ref.watch(cacheStoreProvider),
  ),
);

final sessionRecordRepositoryProvider = Provider<SessionRecordRepository>((
  ref,
) {
  final repo = SessionRecordRepositoryImpl(
    remote: ref.watch(remoteProvider),
    cache: ref.watch(cacheStoreProvider),
    drafts: ref.watch(draftStoreProvider),
    engine: ref.watch(syncEngineProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepositoryImpl(
    remote: ref.watch(remoteProvider),
    cache: ref.watch(cacheStoreProvider),
  ),
);

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepositoryImpl(remote: ref.watch(remoteProvider)),
);

/// Simulasi tanpa sinyal di mode mock (build debug) — untuk mencoba §8 di HP tanpa mematikan jaringan.
final mockOfflineProvider = NotifierProvider<MockOfflineNotifier, bool>(
  MockOfflineNotifier.new,
);

class MockOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool offline) {
    ref.read(mockBackendProvider).offline = offline;
    ref.read(syncEngineProvider).setOffline(offline);
    state = offline;
  }
}
