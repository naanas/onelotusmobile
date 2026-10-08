import 'package:dio/dio.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../ui/feedback/app_error.dart';
import 'api_error_mapper.dart';

/// Klien HTTP ke One Lotus API (Laravel + Sanctum). Semua kegagalan dilempar sebagai [AppError].
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.token,
    this.onUnauthorized,
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
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;

  /// Token Sanctum saat ini (dibaca tiap request).
  final String? Function() token;

  /// 401 → sesi berakhir (ST-15). Data lokal tetap aman.
  final void Function()? onUnauthorized;

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() call,
    T Function(dynamic data) parse,
  ) async {
    try {
      final res = await call();
      return parse(res.data);
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err.type == ErrorCode.authExpired) onUnauthorized?.call();
      throw err;
    }
  }

  /// Respons Laravel resource dibungkus `{ data: ... }`.
  static dynamic unwrap(dynamic body) =>
      body is Map && body.containsKey('data') ? body['data'] : body;

  Future<T> get<T>(
    String path,
    T Function(dynamic data) parse, {
    Map<String, dynamic>? query,
  }) => _send(
    () => dio.get<dynamic>(path, queryParameters: query),
    (d) => parse(unwrap(d)),
  );

  Future<T> post<T>(
    String path,
    Object? body,
    T Function(dynamic data) parse,
  ) =>
      _send(() => dio.post<dynamic>(path, data: body), (d) => parse(unwrap(d)));

  Future<T> put<T>(String path, Object? body, T Function(dynamic data) parse) =>
      _send(() => dio.put<dynamic>(path, data: body), (d) => parse(unwrap(d)));

  Future<T> patch<T>(
    String path,
    Object? body,
    T Function(dynamic data) parse,
  ) => _send(
    () => dio.patch<dynamic>(path, data: body),
    (d) => parse(unwrap(d)),
  );
}

List<T> parseList<T>(dynamic data, T Function(Map<String, dynamic>) f) => [
  for (final e in (data as List)) f((e as Map).cast<String, dynamic>()),
];

Map<String, dynamic> asMap(dynamic data) =>
    (data as Map).cast<String, dynamic>();
