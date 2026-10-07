import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/auth/device_security.dart';
import 'package:onelotus_staff/data/auth/mock_auth_repository.dart';
import 'package:onelotus_staff/data/auth/session_store.dart';

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

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(repo),
    sessionStoreProvider.overrideWithValue(store),
    deviceSecurityProvider.overrideWithValue(device),
    clockProvider.overrideWithValue(() => clock.now),
  ];

  ProviderContainer container() => ProviderContainer(overrides: overrides);
}
