import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/pasien/pasien_api.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';
import 'package:onelotus_staff/pasien/profil/alamat_form_page.dart';

import '../helpers.dart';

/// Server palsu: saran alamat + simpan alamat (mencatat isi yang dikirim).
class _Server implements HttpClientAdapter {
  Map<String, dynamic>? saved;
  final queries = <String>[];

  ResponseBody _json(Object body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
  );

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    switch ((o.method, o.path)) {
      case ('GET', '/v1/geo/search'):
        queries.add(o.queryParameters['q'].toString());
        return _json({
          'data': [
            {
              'title': 'Jalan Ijen',
              'subtitle': 'Oro-Oro Dowo, Klojen, Malang, Jawa Timur',
              'address': 'Jalan Ijen, Oro-Oro Dowo, Klojen, Malang, Jawa Timur, 65115',
              'lat': -7.9643,
              'lng': 112.62506,
            },
          ],
        });
      case ('POST', '/v1/patient/addresses'):
        saved = (o.data as Map).cast<String, dynamic>();
        return _json({
          'data': {...saved!, 'id': 'a1', 'in_service_area': true},
        });
    }
    return _json({'data': []});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<_Server> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2600);
    t.view.devicePixelRatio = 2.7;
    addTearDown(t.view.reset);
    final server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = server;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          pasienApiProvider.overrideWith(
            (ref) => PasienApi(ApiClient(baseUrl: 'http://uji', token: () => 'a', dio: dio), deviceId: () async => 'hp'),
          ),
        ],
        child: TestApp(scroll: false, child: const AlamatFormPage()),
      ),
    );
    await t.pump();
    return server;
  }

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('ketik → saran alamat → pilih → alamat & titik terisi → simpan dengan lat/lng', (t) async {
    final server = await pump(t);
    expect(find.text('Belum ada titik lokasi'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, 'jalan ijen');
    await t.pump(const Duration(milliseconds: 450)); // debounce
    await settle(t);
    expect(server.queries, ['jalan ijen']);
    expect(find.text('Jalan Ijen'), findsOneWidget);

    await t.tap(find.text('Jalan Ijen'));
    await settle(t);
    expect(find.text('Titik lokasi dari alamat yang dipilih'), findsOneWidget);
    expect(find.text('Jalan Ijen, Oro-Oro Dowo, Klojen, Malang, Jawa Timur, 65115'), findsOneWidget);

    await t.tap(find.text('Simpan alamat'));
    await settle(t);
    expect(server.saved?['lat'], -7.9643);
    expect(server.saved?['lng'], 112.62506);
    expect(server.saved?['address'], startsWith('Jalan Ijen'));
    expect(server.saved?['label'], 'Rumah');
  });

  testWidgets('tanpa titik lokasi → tidak disimpan, diminta pilih saran / pakai GPS', (t) async {
    final server = await pump(t);
    await t.enterText(find.widgetWithText(TextField, 'Jalan, nomor rumah, RT/RW, kelurahan'), 'Jl. Mawar 2');
    await t.tap(find.text('Simpan alamat'));
    await settle(t);
    expect(server.saved, isNull);
    final msg = find.textContaining('Pilih alamat dari saran atau gunakan lokasi Anda');
    await t.scrollUntilVisible(msg, 200, scrollable: find.byType(Scrollable).first);
    expect(msg, findsOneWidget);
  });

  testWidgets('ketikan < 3 huruf tidak mencari', (t) async {
    final server = await pump(t);
    await t.enterText(find.byType(TextField).first, 'ij');
    await t.pump(const Duration(milliseconds: 500));
    await settle(t);
    expect(server.queries, isEmpty);
  });
}
