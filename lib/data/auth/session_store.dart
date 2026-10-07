import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan kunci-nilai untuk sesi login. Produksi: Keystore/Keychain via
/// flutter_secure_storage. Tes: [MemorySessionStore].
abstract interface class SessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class MemorySessionStore implements SessionStore {
  MemorySessionStore([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

/// Nama kunci penyimpanan.
abstract final class SessionKeys {
  static const token = 'auth.token';
  static const user = 'auth.user';
  static const activeRole = 'ctx.role';
  static const activeBranch = 'ctx.branch';
  static const loginFails = 'login.fails';
  static const loginLockedUntil = 'login.lockedUntil';

  /// PIN & biometrik disimpan per akun agar login ulang di HP yang sama tidak perlu atur PIN lagi.
  static String pinHash(String userId) => 'pin.$userId.hash';
  static String pinSalt(String userId) => 'pin.$userId.salt';
  static String pinFails(String userId) => 'pin.$userId.fails';
  static String biometric(String userId) => 'bio.$userId';
  static String setupDone(String userId) => 'setup.$userId';
}
