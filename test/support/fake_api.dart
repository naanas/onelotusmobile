import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:onelotus_staff/data/api_client.dart';
import 'package:onelotus_staff/data/auth.dart';
import 'package:onelotus_staff/data/session_store.dart';

typedef FakeHandler = (int, Object?) Function(RequestOptions req);

/// Server palsu untuk tes: peta "METHOD /path" → (status, body JSON). Semua request dicatat di [log].
class FakeApi implements HttpClientAdapter {
  FakeApi(this.routes);

  final Map<String, FakeHandler> routes;
  final log = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    log.add(options);
    final key = '${options.method} ${options.uri.path}';
    final h = routes[key];
    final (status, body) = h == null
        ? (
            404,
            {
              'error': {'message': 'Tidak ada rute $key'},
            },
          )
        : h(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  /// Override provider: klien API memakai server palsu, sesi di memori.
  List<Override> overrides({Map<String, String>? session}) => [
    sessionStoreProvider.overrideWithValue(MemorySessionStore(session)),
    apiClientProvider.overrideWith(
      (ref) => ApiClient(
        baseUrl: 'http://fake',
        token: () => ref.read(authProvider).token,
        onUnauthorized: () => ref.read(authProvider.notifier).expire(),
        dio: Dio(BaseOptions(baseUrl: 'http://fake'))..httpClientAdapter = this,
      ),
    ),
  ];
}

Map<String, dynamic> userJson({
  int id = 1,
  String role = 'admin',
  String name = 'Admin Uji',
}) => {
  'id': id,
  'name': name,
  'username': role == 'admin' ? 'uji.admin' : 'uji.terapis',
  'role': role,
};

/// Sesi tersimpan (sudah login) untuk [MemorySessionStore].
Map<String, String> savedSession({String role = 'admin'}) => {
  'auth.token': '1|token',
  'auth.user': jsonEncode(
    userJson(role: role, name: role == 'admin' ? 'Admin Uji' : 'Terapis Uji'),
  ),
};

Map<String, dynamic> pasienJson({int id = 7, bool withTlp = true}) => {
  'id': id,
  'nomor': 1362,
  'nama': 'Pasien Uji',
  'ttl': '1990-05-01',
  'tlp': withTlp ? '081234567890' : null,
  'alamat': 'Malang',
  'agama': null,
  'gender': 'L',
  'instansi': 'UM',
  'hobi': 'Futsal',
  'tb': 172,
  'bb': 70,
  'tempat_lahir': 'Kediri',
  'created_at': '2026-11-01 02:00:00',
  'kunjungan_terakhir': '2026-11-03 00:00:00',
  'jumlah_pemeriksaan': 1,
};
