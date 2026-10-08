import '../../ui/feedback/app_error.dart';
import '../api/api_client.dart';
import '../models/json.dart';
import '../models/staff_user.dart';
import 'auth_repository.dart';

/// Auth ke One Lotus API (Laravel Sanctum, token per perangkat).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.api);

  final ApiClient api;

  @override
  Future<AppStatus> appStatus() => api.get('/v1/app/status', (d) {
    final m = asMap(d);
    return AppStatus(
      minVersion: m['min_version'] as String? ?? '0.0.0',
      maintenance: m['maintenance'] as bool? ?? false,
      maintenanceUntil: parseDate(m['maintenance_until']),
    );
  });

  @override
  Future<LoginSuccess> login(String username, String password) async {
    try {
      return await api.post(
        '/v1/auth/login',
        {
          'username': username,
          'password': password,
          'device_name': 'onelotus-staff',
        },
        (d) {
          final m = asMap(d);
          return LoginSuccess(
            token: m['token'] as String,
            user: staffUserFromApi(asMap(m['user'])),
          );
        },
      );
    } on AppError catch (e) {
      // 401/422 saat login = kredensial salah (pesan tidak membedakan username/password).
      if (e.code == 'account_disabled') {
        throw const LoginException(LoginFailure.accountDisabled);
      }
      if (e.type == ErrorCode.authExpired || e.type == ErrorCode.validation) {
        throw const LoginException(LoginFailure.invalidCredentials);
      }
      rethrow;
    }
  }

  @override
  Future<void> changePassword(
    String token, {
    required String current,
    required String next,
  }) => api.post('/v1/auth/password', {
    'current_password': current,
    'password': next,
  }, (_) {});

  @override
  Future<void> requestPasswordReset(String username, {String? note}) =>
      api.post('/v1/auth/password-reset-requests', {
        'username': username,
        'note': note,
      }, (_) {});

  @override
  Future<void> logout(String token) =>
      api.post('/v1/auth/logout', null, (_) {});
}

/// User dari API: `roles` berisi id peran, `branches` daftar cabang, `must_change_password`.
StaffUser staffUserFromApi(Map<String, dynamic> m) => StaffUser(
  id: m['id'].toString(),
  username: m['username'] as String,
  name: m['name'] as String,
  roles: [
    for (final r in (m['roles'] as List? ?? const []))
      ?Role.fromId(r.toString()),
  ],
  branches: [
    for (final b in (m['branches'] as List? ?? const []))
      Branch(
        id: (b as Map)['id'].toString(),
        name: b['name'] as String,
        address: b['address'] as String? ?? '',
      ),
  ],
  mustChangePassword: m['must_change_password'] as bool? ?? false,
);
