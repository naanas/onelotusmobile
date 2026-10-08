import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../ui/feedback/app_error.dart';
import '../providers.dart' show apiClientProvider;
import 'api_auth_repository.dart';
import '../models/staff_user.dart';
import 'auth_repository.dart';
import 'device_security.dart';
import 'mock_auth_repository.dart';
import 'session_store.dart';

enum AuthPhase {
  /// UM-01 sedang memeriksa sesi.
  booting,

  /// Pertama buka tanpa koneksi & belum pernah login (UM-01 edge case).
  needsConnection,
  signedOut,

  /// `auth_expired` → layar penuh "Sesi login berakhir" (ST-15).
  sessionExpired,

  /// UM-05: ganti password sementara / atur PIN di perangkat ini.
  firstLogin,

  /// UM-08: akun punya >1 peran atau cabang dan belum memilih.
  chooseContext,

  /// UM-07: kunci aplikasi.
  locked,
  ready,
}

class AuthState {
  const AuthState({
    this.phase = AuthPhase.booting,
    this.user,
    this.token,
    this.activeRole,
    this.activeBranch,
    this.offline = false,
    this.biometricEnabled = false,
    this.firstLoginStartStep = 1,
  });

  final AuthPhase phase;
  final StaffUser? user;
  final String? token;
  final Role? activeRole;
  final Branch? activeBranch;

  /// Masuk dengan data lokal karena API tidak terjangkau (UM-01).
  final bool offline;
  final bool biometricEnabled;

  /// 1 = ganti password sementara, 2 = langsung atur PIN.
  final int firstLoginStartStep;

  AuthState copyWith({
    AuthPhase? phase,
    StaffUser? user,
    String? token,
    Role? activeRole,
    Branch? activeBranch,
    bool? offline,
    bool? biometricEnabled,
    int? firstLoginStartStep,
  }) => AuthState(
    phase: phase ?? this.phase,
    user: user ?? this.user,
    token: token ?? this.token,
    activeRole: activeRole ?? this.activeRole,
    activeBranch: activeBranch ?? this.activeBranch,
    offline: offline ?? this.offline,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    firstLoginStartStep: firstLoginStartStep ?? this.firstLoginStartStep,
  );
}

sealed class LoginOutcome {
  const LoginOutcome();
}

class LoginOk extends LoginOutcome {
  const LoginOk();
}

class LoginInvalid extends LoginOutcome {
  const LoginInvalid(this.remainingAttempts);
  final int remainingAttempts;
}

class LoginLocked extends LoginOutcome {
  const LoginLocked(this.until);
  final DateTime until;
}

class LoginDisabled extends LoginOutcome {
  const LoginDisabled();
}

class LoginError extends LoginOutcome {
  const LoginError(this.error);
  final AppError error;
}

sealed class PinOutcome {
  const PinOutcome();
}

class PinOk extends PinOutcome {
  const PinOk();
}

class PinWrong extends PinOutcome {
  const PinWrong(this.remainingAttempts);
  final int remainingAttempts;
}

/// Salah 5× → logout paksa (UM-07).
class PinForcedLogout extends PinOutcome {
  const PinForcedLogout();
}

/// Aturan keamanan (UM-04, UM-07, §10).
abstract final class AuthRules {
  static const maxLoginAttempts = 5;
  static const loginLockout = Duration(minutes: 5);
  static const maxPinAttempts = 5;
  static const pinLength = 6;
  static const inactivityLock = Duration(minutes: 5);
  static const minPasswordLength = 8;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AppConfig.useMock
      ? MockAuthRepository()
      : ApiAuthRepository(ref.watch(apiClientProvider)),
);
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);
final deviceSecurityProvider = Provider<DeviceSecurity>(
  (ref) => PlatformDeviceSecurity(),
);
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);
  DeviceSecurity get _device => ref.read(deviceSecurityProvider);
  DateTime _now() => ref.read(clockProvider)();

  /// Password sementara, disimpan di memori hanya selama UM-05 (syarat "berbeda dari sementara").
  String? _tempPassword;
  DateTime? _backgroundedAt;

  @override
  AuthState build() => const AuthState();

  // ── UM-01 ────────────────────────────────────────────────────────────────

  /// [minDuration]: splash tampil minimal selama ini agar animasi mekar selesai (UM-01: maks 2 dtk).
  Future<void> bootstrap({Duration minDuration = Duration.zero}) async {
    state = const AuthState();
    final minWait = Future<void>.delayed(minDuration);
    final next = await _resolveBoot();
    await minWait;
    state = next;
  }

  Future<AuthState> _resolveBoot() async {
    final token = await _store.read(SessionKeys.token);
    final userJson = await _store.read(SessionKeys.user);
    final user = userJson == null
        ? null
        : StaffUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);

    var offline = false;
    try {
      await _repo.appStatus().timeout(const Duration(seconds: 5));
      // TODO(UM-02/UM-03): bandingkan versi minimum & mode pemeliharaan.
    } catch (_) {
      offline = true;
    }

    if (token == null || user == null) {
      return AuthState(
        phase: offline ? AuthPhase.needsConnection : AuthPhase.signedOut,
      );
    }
    return _afterAuthenticated(user, token, offline: offline, coldStart: true);
  }

  // ── UM-04 ────────────────────────────────────────────────────────────────

  /// Sisa waktu kunci login bila gagal 5× (UM-04b), atau null.
  Future<DateTime?> loginLockedUntil() async {
    final raw = await _store.read(SessionKeys.loginLockedUntil);
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null || !until.isAfter(_now())) return null;
    return until;
  }

  Future<LoginOutcome> login(
    String username,
    String password, {
    bool remember = true,
  }) async {
    final lockedUntil = await loginLockedUntil();
    if (lockedUntil != null) return LoginLocked(lockedUntil);

    try {
      final res = await _repo.login(username.trim(), password);
      await _store.delete(SessionKeys.loginFails);
      await _store.delete(SessionKeys.loginLockedUntil);
      if (remember) {
        await _store.write(SessionKeys.token, res.token);
        await _store.write(SessionKeys.user, jsonEncode(res.user.toJson()));
      } else {
        await _store.delete(SessionKeys.token);
        await _store.delete(SessionKeys.user);
      }
      if (res.user.mustChangePassword) _tempPassword = password;
      state = await _afterAuthenticated(
        res.user,
        res.token,
        offline: false,
        coldStart: false,
      );
      return const LoginOk();
    } on LoginException catch (e) {
      if (e.reason == LoginFailure.accountDisabled) {
        return const LoginDisabled();
      }
      final fails =
          int.parse(await _store.read(SessionKeys.loginFails) ?? '0') + 1;
      if (fails >= AuthRules.maxLoginAttempts) {
        final until = _now().add(AuthRules.loginLockout);
        await _store.write(
          SessionKeys.loginLockedUntil,
          until.toIso8601String(),
        );
        await _store.delete(SessionKeys.loginFails);
        return LoginLocked(until);
      }
      await _store.write(SessionKeys.loginFails, '$fails');
      return LoginInvalid(AuthRules.maxLoginAttempts - fails);
    } on AppError catch (e) {
      return LoginError(e);
    } catch (_) {
      return const LoginError(AppError(ErrorCode.unknown));
    }
  }

  Future<void> requestPasswordReset(String username, {String? note}) =>
      _repo.requestPasswordReset(username.trim(), note: note);

  // ── UM-05 ────────────────────────────────────────────────────────────────

  /// Validasi password baru; null = valid.
  String? validateNewPassword(String next) {
    if (next.length < AuthRules.minPasswordLength) {
      return 'Minimal ${AuthRules.minPasswordLength} karakter.';
    }
    if (_tempPassword != null && next == _tempPassword) {
      return 'Harus berbeda dari password sementara.';
    }
    return null;
  }

  bool isSameAsTemporary(String next) =>
      _tempPassword != null && next == _tempPassword;

  Future<void> changeTemporaryPassword(String next) async {
    final s = state;
    await _repo.changePassword(
      s.token!,
      current: _tempPassword ?? '',
      next: next,
    );
    _tempPassword = null;
    final user = s.user!.copyWith(mustChangePassword: false);
    if (await _store.read(SessionKeys.token) != null) {
      await _store.write(SessionKeys.user, jsonEncode(user.toJson()));
    }
    state = s.copyWith(user: user);
  }

  Future<void> setPin(String pin) async {
    final id = state.user!.id;
    final salt = _randomSalt();
    await _store.write(SessionKeys.pinSalt(id), salt);
    await _store.write(SessionKeys.pinHash(id), _hash(pin, salt));
    await _store.delete(SessionKeys.pinFails(id));
  }

  Future<bool> biometricAvailable() => _device.biometricAvailable();

  /// Aktifkan biometrik — minta verifikasi sekali agar yakin sidik jari bekerja.
  Future<bool> enableBiometric() async {
    final ok = await _device.authenticateBiometric(
      'Verifikasi untuk membuka One Lotus dengan biometrik',
    );
    if (ok) {
      await _store.write(SessionKeys.biometric(state.user!.id), '1');
      state = state.copyWith(biometricEnabled: true);
    }
    return ok;
  }

  Future<bool> requestNotificationPermission() =>
      _device.requestNotificationPermission();

  /// Selesai langkah 1–3. Lanjut ke pilih cabang & peran bila perlu.
  Future<void> completeFirstLogin() async {
    final s = state;
    await _store.write(SessionKeys.setupDone(s.user!.id), '1');
    state = await _afterAuthenticated(
      s.user!,
      s.token!,
      offline: s.offline,
      coldStart: false,
    );
  }

  // ── UM-08 ────────────────────────────────────────────────────────────────

  Future<void> chooseContext(Role role, Branch branch) async {
    await _store.write(SessionKeys.activeRole, role.id);
    await _store.write(SessionKeys.activeBranch, branch.id);
    state = state.copyWith(
      phase: AuthPhase.ready,
      activeRole: role,
      activeBranch: branch,
    );
  }

  // ── UM-07 ────────────────────────────────────────────────────────────────

  Future<PinOutcome> unlockWithPin(String pin) async {
    final id = state.user!.id;
    final salt = await _store.read(SessionKeys.pinSalt(id));
    final hash = await _store.read(SessionKeys.pinHash(id));
    if (salt != null && hash == _hash(pin, salt)) {
      await _store.delete(SessionKeys.pinFails(id));
      state = state.copyWith(phase: AuthPhase.ready);
      return const PinOk();
    }
    final fails =
        int.parse(await _store.read(SessionKeys.pinFails(id)) ?? '0') + 1;
    if (fails >= AuthRules.maxPinAttempts) {
      // Data lokal belum sinkron tetap disimpan (outbox tidak disentuh).
      await _clearPin(id);
      await logout();
      return const PinForcedLogout();
    }
    await _store.write(SessionKeys.pinFails(id), '$fails');
    return PinWrong(AuthRules.maxPinAttempts - fails);
  }

  Future<int> remainingPinAttempts() async {
    final id = state.user?.id;
    if (id == null) return AuthRules.maxPinAttempts;
    return AuthRules.maxPinAttempts -
        int.parse(await _store.read(SessionKeys.pinFails(id)) ?? '0');
  }

  Future<bool> unlockWithBiometric() async {
    if (!state.biometricEnabled) return false;
    final ok = await _device.authenticateBiometric('Buka One Lotus');
    if (ok) {
      await _store.delete(SessionKeys.pinFails(state.user!.id));
      state = state.copyWith(phase: AuthPhase.ready);
    }
    return ok;
  }

  /// "Lupa PIN? Masuk dengan password" → PIN dihapus, login ulang, atur PIN baru.
  Future<void> forgotPin() async {
    final id = state.user?.id;
    if (id != null) await _clearPin(id);
    await logout();
  }

  void onBackground() => _backgroundedAt = _now();

  /// Kunci bila kembali setelah tidak aktif ≥ 5 menit.
  Future<void> onForeground() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || state.phase != AuthPhase.ready) return;
    if (_now().difference(since) < AuthRules.inactivityLock) return;
    if (await _hasPin(state.user!.id)) {
      state = state.copyWith(phase: AuthPhase.locked);
    }
  }

  // ── Logout & sesi berakhir ───────────────────────────────────────────────

  Future<void> logout() async {
    final token = state.token;
    if (token != null) unawaited(_repo.logout(token).catchError((_) {}));
    for (final k in [
      SessionKeys.token,
      SessionKeys.user,
      SessionKeys.activeRole,
      SessionKeys.activeBranch,
    ]) {
      await _store.delete(k);
    }
    _tempPassword = null;
    state = const AuthState(phase: AuthPhase.signedOut);
  }

  /// Dipanggil AppFeedback untuk `auth_expired` (401). Data lokal tetap aman.
  Future<void> expireSession() async {
    await logout();
    state = const AuthState(phase: AuthPhase.sessionExpired);
  }

  void acknowledgeSessionExpired() =>
      state = const AuthState(phase: AuthPhase.signedOut);

  // ── internal ─────────────────────────────────────────────────────────────

  Future<AuthState> _afterAuthenticated(
    StaffUser user,
    String token, {
    required bool offline,
    required bool coldStart,
  }) async {
    final base = AuthState(
      user: user,
      token: token,
      offline: offline,
      biometricEnabled:
          await _store.read(SessionKeys.biometric(user.id)) == '1',
    );
    final setupDone = await _store.read(SessionKeys.setupDone(user.id)) == '1';
    final hasPin = await _hasPin(user.id);
    if (user.mustChangePassword || !setupDone || !hasPin) {
      return base.copyWith(
        phase: AuthPhase.firstLogin,
        firstLoginStartStep: user.mustChangePassword ? 1 : 2,
      );
    }

    final role = Role.fromId(await _store.read(SessionKeys.activeRole));
    final branchId = await _store.read(SessionKeys.activeBranch);
    final branch = user.branches.where((b) => b.id == branchId).firstOrNull;
    if (role == null || !user.roles.contains(role) || branch == null) {
      if (user.needsContextChoice) {
        return base.copyWith(phase: AuthPhase.chooseContext);
      }
      await _store.write(SessionKeys.activeRole, user.roles.first.id);
      await _store.write(SessionKeys.activeBranch, user.branches.first.id);
      return base.copyWith(
        phase: coldStart ? AuthPhase.locked : AuthPhase.ready,
        activeRole: user.roles.first,
        activeBranch: user.branches.first,
      );
    }
    // UM-01: token valid & kunci aktif → UM-07.
    return base.copyWith(
      phase: coldStart ? AuthPhase.locked : AuthPhase.ready,
      activeRole: role,
      activeBranch: branch,
    );
  }

  Future<bool> _hasPin(String userId) async =>
      await _store.read(SessionKeys.pinHash(userId)) != null;

  Future<void> _clearPin(String userId) async {
    await _store.delete(SessionKeys.pinHash(userId));
    await _store.delete(SessionKeys.pinSalt(userId));
    await _store.delete(SessionKeys.pinFails(userId));
    await _store.delete(SessionKeys.biometric(userId));
  }

  static String _randomSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
