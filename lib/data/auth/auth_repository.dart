import '../models/staff_user.dart';

class LoginSuccess {
  const LoginSuccess({required this.token, required this.user});
  final String token;
  final StaffUser user;
}

/// Hasil gagal login yang perlu pesan khusus di UM-04.
enum LoginFailure {
  /// Pesan tidak membedakan username vs password (UM-04).
  invalidCredentials,
  accountDisabled,
}

class LoginException implements Exception {
  const LoginException(this.reason);
  final LoginFailure reason;
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

/// Kontrak auth ke One Lotus API (Laravel + Sanctum). Implementasi API menyusul di Tahap 4.
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

  /// Respons selalu sama walau username tidak terdaftar (UM-06).
  Future<void> requestPasswordReset(String username, {String? note});

  Future<void> logout(String token);
}
