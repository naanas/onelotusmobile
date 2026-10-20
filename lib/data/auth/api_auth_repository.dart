import 'dart:io' show Platform;

import 'package:dio/dio.dart';

import '../../core/format.dart';
import '../../ui/feedback/app_error.dart';
import '../api/api_client.dart';
import '../api/v1.dart';
import '../models/json.dart';
import '../models/staff_user.dart';
import 'auth_repository.dart';

/// Auth ke One Lotus API v1 (§4): login staf → access JWT + refresh token per perangkat.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.api, {required this.deviceId});

  final ApiClient api;
  final Future<String> Function() deviceId;

  @override
  Future<AppStatus> appStatus() => api.get('/v1/app/config', (d) {
    final m = asMap(d);
    final min = m['min_version'] is Map ? asMap(m['min_version']) : const <String, dynamic>{};
    final maint = m['maintenance'] is Map ? asMap(m['maintenance']) : const <String, dynamic>{};
    V1.policyVersion = m['policy_version'] as String? ?? V1.policyVersion;
    return AppStatus(
      minVersion: min['staff'] as String? ?? '0.0.0',
      maintenance: maint['active'] as bool? ?? false,
      maintenanceUntil: parseDate(maint['until']),
    );
  });

  static String get _platform {
    try {
      return Platform.isIOS ? 'ios' : 'android';
    } catch (_) {
      return 'android';
    }
  }

  TokenPair _pair(dynamic d) {
    final m = asMap(d);
    return TokenPair(access: m['access_token'] as String, refresh: m['refresh_token'] as String);
  }

  /// Profil + peran dari `/v1/me`, alamat cabang dari `/v1/branches` (token baru dipasang eksplisit).
  Future<StaffUser> _me(String access) async {
    final headers = {'Authorization': 'Bearer $access'};
    final me = await api.dio.get<dynamic>('/v1/me', options: Options(headers: headers));
    final branches = <String, Branch>{};
    try {
      final res = await api.dio.get<dynamic>('/v1/branches', options: Options(headers: headers));
      for (final b in (asMap(res.data)['data'] as List? ?? const [])) {
        final m = asMap(b);
        branches[m['id'].toString()] = Branch(
          id: m['id'].toString(),
          name: m['name'] as String,
          address: m['address'] as String? ?? '',
        );
      }
    } on DioException catch (_) {
      // Alamat cabang hanya pelengkap UM-08.
    }
    return V1.me(asMap(ApiClient.unwrap(me.data)), branches: branches);
  }

  @override
  Future<LoginSuccess> login(String username, String password) async {
    try {
      final pair = await api.post('/v1/auth/staff/login', {
        'username': username,
        'password': password,
        'device_id': await deviceId(),
        'device_name': 'onelotus-staff',
        'platform': _platform,
        'app_version': kAppVersion,
      }, _pair);
      final user = await _me(pair.access);
      return LoginSuccess(token: pair.access, refreshToken: pair.refresh, user: user);
    } on DioException catch (e) {
      // _me() memakai dio langsung.
      throw AppError(ErrorCode.unknown, refId: e.response?.headers.value('x-request-ref'));
    } on AppError catch (e) {
      // Pesan tidak membedakan username/password (UM-04).
      switch (e.apiCode) {
        case 'account_inactive':
          throw const LoginException(LoginFailure.accountDisabled);
        case 'account_locked':
          final sec = (e.details['retry_after_sec'] as num?)?.toInt() ?? 300;
          throw LoginException(LoginFailure.locked, retryAfter: Duration(seconds: sec));
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
  }) => api.post('/v1/auth/staff/password', {
    'old_password': current,
    'new_password': next,
  }, (_) {});

  @override
  Future<TokenPair?> firstLogin(String newPassword) =>
      api.post('/v1/auth/staff/first-login', {'new_password': newPassword}, _pair);

  @override
  Future<TokenPair?> refresh(String refreshToken) async {
    try {
      // Langsung lewat dio: refresh tidak boleh memicu refresh lagi.
      final res = await api.dio.post<dynamic>(
        '/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return _pair(ApiClient.unwrap(res.data));
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) return null;
      rethrow;
    }
  }

  @override
  Future<void> requestPasswordReset(String username, {String? note}) =>
      api.post('/v1/auth/staff/forgot', {'username': username, 'note': note}, (_) {});

  @override
  Future<void> logout(String token) => api.post('/v1/auth/logout', null, (_) {});
}
