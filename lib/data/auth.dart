import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../ui/feedback/app_error.dart';
import 'api_client.dart';
import 'models.dart';
import 'session_store.dart';

/// Status login. [ready] = sesi tersimpan sudah dibaca saat aplikasi dibuka.
class AuthState {
  const AuthState({
    this.ready = false,
    this.token,
    this.user,
    this.expired = false,
  });

  final bool ready;
  final String? token;
  final AppUser? user;

  /// Token ditolak server (dicabut / kedaluwarsa) → layar masuk menampilkan pemberitahuan.
  final bool expired;

  bool get loggedIn => token != null && user != null;
  bool get isAdmin => user?.isAdmin ?? false;
}

final sessionStoreProvider = Provider<SessionStore>(
  (_) => SecureSessionStore(),
);

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Klien HTTP. Token dibaca setiap request; 401 = sesi berakhir → keluar.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: AppConfig.apiUrl,
    token: () => ref.read(authProvider).token,
    onUnauthorized: () => ref.read(authProvider.notifier).expire(),
  ),
);

abstract final class _Keys {
  static const token = 'auth.token';
  static const user = 'auth.user';
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    unawaited(_restore());
    return const AuthState();
  }

  SessionStore get _store => ref.read(sessionStoreProvider);

  Future<void> _restore() async {
    String? token;
    AppUser? user;
    try {
      token = await _store.read(_Keys.token);
      final raw = await _store.read(_Keys.user);
      if (raw != null) {
        user = AppUser.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>(),
        );
      }
    } catch (_) {
      token = null;
    }
    if (token == null || user == null) {
      state = const AuthState(ready: true);
      return;
    }
    state = AuthState(ready: true, token: token, user: user);
    // Perbarui nama/peran dari server (mis. peran diubah admin). Offline → pakai data tersimpan.
    try {
      final me = await ref
          .read(apiClientProvider)
          .get('/v1/me', (d) => AppUser.fromJson((d as Map).cast()));
      if (state.token == token) {
        state = AuthState(ready: true, token: token, user: me);
        await _store.write(_Keys.user, jsonEncode(me.toJson()));
      }
    } on AppError {
      // 401 sudah ditangani onUnauthorized; error jaringan diabaikan.
    }
  }

  /// Masuk dengan username & password. Melempar [AppError] bila gagal.
  Future<void> login(String username, String password) async {
    final data = await ref.read(apiClientProvider).post('/v1/login', {
      'username': username.trim(),
      'password': password,
      'device_name': 'Aplikasi One Lotus',
    }, (d) => (d as Map).cast<String, dynamic>());
    final token = data['token'] as String;
    final user = AppUser.fromJson((data['user'] as Map).cast());
    await _store.write(_Keys.token, token);
    await _store.write(_Keys.user, jsonEncode(user.toJson()));
    state = AuthState(ready: true, token: token, user: user);
  }

  Future<void> logout() async {
    if (state.token != null) {
      try {
        await ref.read(apiClientProvider).post('/v1/logout', null, (_) {});
      } on AppError {
        // Tetap keluar di HP walau server tidak terjangkau.
      }
    }
    await _clear();
    state = const AuthState(ready: true);
  }

  /// Server menolak token.
  void expire() {
    if (state.token == null) return;
    unawaited(_clear());
    state = const AuthState(ready: true, expired: true);
  }

  Future<void> _clear() async {
    await _store.delete(_Keys.token);
    await _store.delete(_Keys.user);
  }
}
