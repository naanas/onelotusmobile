import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

/// Adapter palsu: selalu membalas 401 dengan kode error [code].
class _Always401 implements HttpClientAdapter {
  _Always401(this.code);
  final String code;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode({'error': {'code': code, 'message': 'x', 'ref': 'OL-TEST'}}),
      401,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<(int refreshed, int expired, AppError err)> post(String code) async {
    var refreshed = 0, expired = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = _Always401(code);
    final client = ApiClient(
      baseUrl: 'http://uji',
      token: () => 'tok',
      dio: dio,
      refresh: () async {
        refreshed++;
        return false;
      },
      onUnauthorized: () => expired++,
    );
    try {
      await client.post('/v1/auth/staff/login', {'username': 'a'}, (d) => d);
      fail('harus melempar AppError');
    } on AppError catch (e) {
      return (refreshed, expired, e);
    }
  }

  test('password salah (401 auth_invalid) tidak dianggap sesi habis', () async {
    final (refreshed, expired, err) = await post('auth_invalid');
    expect(refreshed, 0);
    expect(expired, 0);
    expect(err.apiCode, 'auth_invalid');
  });

  test('sesi habis (401 auth_expired) → refresh lalu keluar', () async {
    final (refreshed, expired, err) = await post('auth_expired');
    expect(refreshed, 1);
    expect(expired, 1);
    expect(err.type, ErrorCode.authExpired);
  });
}
