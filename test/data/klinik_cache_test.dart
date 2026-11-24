import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/features/klinik/klinik_api.dart';
import 'package:onelotus_staff/features/klinik/klinik_cache.dart';

/// Server palsu `/v1/klinik/pasien`: 200 + ETag, lalu 304 bila If-None-Match cocok.
class _Server implements HttpClientAdapter {
  int hits = 0;
  final seenEtag = <String?>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    hits++;
    final inm = o.headers['If-None-Match'] as String?;
    seenEtag.add(inm);
    if (inm == 'W/"v1"') {
      return ResponseBody.fromString('', 304, headers: {'etag': ['W/"v1"']});
    }
    final json = jsonEncode({
      'data': [
        {'id': 'p1', 'nomor': 1407, 'nama': 'Budi', 'gender': 'L'},
      ],
      'meta': {'page': 1, 'per_page': 30, 'total': 1},
    });
    return ResponseBody.fromString(json, 200, headers: {
      'content-type': ['application/json'],
      'etag': ['W/"v1"'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('cache: 200 → segar tanpa request → kedaluwarsa → 304 pakai isi lama', () async {
    final server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = server;
    final cache = KlinikCache();
    final api = KlinikApi(ApiClient(baseUrl: 'http://x', token: () => 't', dio: dio), cache);

    final a = await api.pasien();
    expect(a.items.single.nama, 'Budi');
    expect(a.total, 1);
    expect(server.hits, 1);

    // Masih segar: tidak ada request.
    final b = await api.pasien();
    expect(b.items.single.nomor, 1407);
    expect(server.hits, 1);

    // Ditandai lewat → request bersyarat → 304 → isi lama.
    cache.expire();
    final c = await api.pasien();
    expect(server.hits, 2);
    expect(server.seenEtag.last, 'W/"v1"');
    expect(c.items.single.nama, 'Budi');
  });
}
