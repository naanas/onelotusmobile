import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../ui/feedback/app_error.dart';
import 'api_error_mapper.dart';

/// Satu halaman daftar API v1: `{ data: [...], page: { next_cursor, has_more } }`.
class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor, this.hasMore = false});

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}

/// Klien HTTP ke One Lotus API v1 (Go). Semua kegagalan dilempar sebagai [AppError].
/// Header wajib (§3): `Authorization`, `X-App-Version`, `X-Device-Id`; `X-Branch-Id` = cabang aktif.
/// Access token 15 menit: 401 `auth_expired` → [refresh] sekali lalu permintaan diulang.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.token,
    this.onUnauthorized,
    this.refresh,
    this.deviceId,
    this.branchId,
    Dio? dio,
  }) : dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: AppConfig.requestTimeout,
               sendTimeout: AppConfig.requestTimeout,
               receiveTimeout: AppConfig.requestTimeout,
               headers: {
                 'Accept': 'application/json',
                 'X-App-Version': kAppVersion,
               },
             ),
           ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = token();
          if (t != null && !options.headers.containsKey('Authorization')) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          final dev = deviceId?.call();
          if (dev != null) options.headers['X-Device-Id'] = dev;
          final br = branchId?.call();
          if (br != null && !options.headers.containsKey('X-Branch-Id')) {
            options.headers['X-Branch-Id'] = br;
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;

  /// Access token saat ini (dibaca tiap request).
  final String? Function() token;

  /// Refresh token gagal / dicabut → sesi berakhir (ST-15). Data lokal tetap aman.
  final void Function()? onUnauthorized;

  /// Tukar refresh token → access token baru. `true` bila berhasil.
  final Future<bool> Function()? refresh;
  final String? Function()? deviceId;
  final String? Function()? branchId;

  Future<bool>? _refreshing;

  Future<bool> _refreshOnce() {
    final r = refresh;
    if (r == null) return Future.value(false);
    // Banyak request gagal bersamaan → satu kali refresh saja.
    return _refreshing ??= r().whenComplete(() => _refreshing = null);
  }

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() call,
    T Function(dynamic data) parse,
  ) async {
    try {
      final res = await call();
      return parse(res.data);
    } on DioException catch (e) {
      var err = mapDioError(e);
      if (err.type == ErrorCode.authExpired && await _refreshOnce()) {
        try {
          final res = await call();
          return parse(res.data);
        } on DioException catch (e2) {
          err = mapDioError(e2);
        }
      }
      if (err.type == ErrorCode.authExpired) onUnauthorized?.call();
      throw err;
    }
  }

  /// Respons sukses dibungkus `{ data: ... }`.
  static dynamic unwrap(dynamic body) =>
      body is Map && body.containsKey('data') ? body['data'] : body;

  Future<T> get<T>(
    String path,
    T Function(dynamic data) parse, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _send(
    () => dio.get<dynamic>(path, queryParameters: _clean(query), options: Options(headers: headers)),
    (d) => parse(unwrap(d)),
  );

  /// Daftar berkursor.
  Future<CursorPage<T>> getPage<T>(
    String path,
    T Function(Map<String, dynamic>) item, {
    Map<String, dynamic>? query,
  }) => _send(
    () => dio.get<dynamic>(path, queryParameters: _clean(query)),
    (body) {
      final m = asMap(body);
      final page = m['page'] is Map ? asMap(m['page']) : const <String, dynamic>{};
      return CursorPage(
        items: parseList(m['data'], item),
        nextCursor: page['next_cursor'] as String?,
        hasMore: page['has_more'] as bool? ?? false,
      );
    },
  );

  /// GET tanpa membuka `{ data }`.
  Future<T> getBody<T>(
    String path,
    T Function(dynamic body) parse, {
    Map<String, dynamic>? query,
  }) => _send(
    () => dio.get<dynamic>(path, queryParameters: _clean(query)),
    parse,
  );

  Future<T> delete<T>(String path, T Function(dynamic data) parse) =>
      _send(() => dio.delete<dynamic>(path), (d) => parse(unwrap(d)));

  Future<T> post<T>(
    String path,
    Object? body,
    T Function(dynamic data) parse, {
    Map<String, String>? headers,
  }) => _send(
    () => dio.post<dynamic>(path, data: body, options: Options(headers: headers)),
    (d) => parse(unwrap(d)),
  );

  Future<T> put<T>(
    String path,
    Object? body,
    T Function(dynamic data) parse, {
    Map<String, String>? headers,
  }) => _send(
    () => dio.put<dynamic>(path, data: body, options: Options(headers: headers)),
    (d) => parse(unwrap(d)),
  );

  Future<T> patch<T>(
    String path,
    Object? body,
    T Function(dynamic data) parse, {
    Map<String, String>? headers,
  }) => _send(
    () =>
        dio.patch<dynamic>(path, data: body, options: Options(headers: headers)),
    (d) => parse(unwrap(d)),
  );

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) => q == null
      ? null
      : {
          for (final e in q.entries)
            if (e.value != null && e.value != '') e.key: e.value,
        };
}

List<T> parseList<T>(dynamic data, T Function(Map<String, dynamic>) f) => [
  for (final e in (data as List? ?? const [])) f((e as Map).cast<String, dynamic>()),
];

Map<String, dynamic> asMap(dynamic data) =>
    (data as Map).cast<String, dynamic>();
