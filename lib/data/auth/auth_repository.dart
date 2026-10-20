import '../models/staff_user.dart';

class LoginSuccess {
  const LoginSuccess({required this.token, required this.user, this.refreshToken});

  /// Access token (JWT 15 menit).
  final String token;

  /// Refresh token (30 hari, dirotasi tiap dipakai).
  final String? refreshToken;
  final StaffUser user;
}

/// Pasangan token baru dari refresh / login pertama.
class TokenPair {
  const TokenPair({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

/// Hasil gagal login yang perlu pesan khusus di UM-04.
enum LoginFailure {
  /// Pesan tidak membedakan username vs password (UM-04).
  invalidCredentials,
  accountDisabled,

  /// Server mengunci akun 5 menit setelah 5× salah (`423 account_locked`).
  locked,
}

class LoginException implements Exception {
  const LoginException(this.reason, {this.retryAfter});
  final LoginFailure reason;
  final Duration? retryAfter;
}

/// Status aplikasi dari API saat splash (UM-01 → UM-02/UM-03).
class AppStatus {
  const AppStatus({
    this.minVersion = '1.0.0',
    this.maintenance = false,
    this.maintenanceUntil,
  });
  final String minVersion;
  final bool maintenance;
  final DateTime? maintenanceUntil;
}

/// Kontrak auth ke One Lotus API v1 (JWT access 15 menit + refresh token, §4).
abstract interface class AuthRepository {
  Future<AppStatus> appStatus();

  /// Lempar [LoginException] untuk kredensial salah / akun nonaktif, `AppError` untuk lainnya.
  Future<LoginSuccess> login(String username, String password);

  /// Ganti password sementara (UM-05) atau biasa (UM-12).
  Future<void> changePassword(
    String token, {
    required String current,
    required String next,
  });

  /// Login pertama (UM-05): ganti password sementara → sesi lama dicabut, token baru dikembalikan.
  Future<TokenPair?> firstLogin(String newPassword);

  /// Tukar refresh token; null bila ditolak (dicabut/kedaluwarsa).
  Future<TokenPair?> refresh(String refreshToken);

  /// Respons selalu sama walau username tidak terdaftar (UM-06).
  Future<void> requestPasswordReset(String username, {String? note});

  Future<void> logout(String token);
}
