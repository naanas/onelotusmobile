import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/auth/device_security.dart';
import 'package:onelotus_staff/data/auth/mock_auth_repository.dart';
import 'package:onelotus_staff/data/auth/session_store.dart';
import 'package:onelotus_staff/data/local/kv_store.dart';
import 'package:onelotus_staff/data/providers.dart';
import 'package:onelotus_staff/data/remote/mock_backend.dart';
import 'package:onelotus_staff/data/sync/outbox.dart';

class FakeDeviceSecurity implements DeviceSecurity {
  bool available = true;
  bool biometricResult = true;
  int biometricCalls = 0;

  @override
  Future<bool> biometricAvailable() async => available;

  @override
  Future<bool> authenticateBiometric(String reason) async {
    biometricCalls++;
    return biometricResult;
  }

  @override
  Future<bool> requestNotificationPermission() async => true;
}

class FakeClock {
  DateTime now = DateTime(2026, 10, 6, 9);
  void advance(Duration d) => now = now.add(d);
}

class AuthHarness {
  AuthHarness({MemorySessionStore? store})
    : store = store ?? MemorySessionStore(),
      device = FakeDeviceSecurity(),
      clock = FakeClock(),
      repo = MockAuthRepository(latency: Duration.zero);

  final MemorySessionStore store;
  final FakeDeviceSecurity device;
  final FakeClock clock;
  final MockAuthRepository repo;
  final outbox = MemoryOutboxStore();
  final drafts = MemoryKvStore();
  final cache = MemoryKvStore();
  final backend = MockBackend(latency: Duration.zero);

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(repo),
    sessionStoreProvider.overrideWithValue(store),
    deviceSecurityProvider.overrideWithValue(device),
    clockProvider.overrideWithValue(() => clock.now),
    // Penyimpanan lokal di memori (tanpa sqflite) & backend contoh tanpa jeda.
    outboxStoreProvider.overrideWithValue(outbox),
    draftStoreProvider.overrideWithValue(drafts),
    cacheStoreProvider.overrideWithValue(cache),
    mockBackendProvider.overrideWithValue(backend),
    connectivityProvider.overrideWithValue(const Stream<bool>.empty()),
  ];

  ProviderContainer container() => ProviderContainer(overrides: overrides);
}
