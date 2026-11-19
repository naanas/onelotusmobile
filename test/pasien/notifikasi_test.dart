import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/pasien/pasien_api.dart';
import 'package:onelotus_staff/pasien/pasien_routes.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';
import 'package:onelotus_staff/pasien/profil/notifikasi_page.dart';

import '../helpers.dart';

/// Server palsu: satu notifikasi belum dibaca (pembayaran gagal) + satu sudah dibaca.
class _Server implements HttpClientAdapter {
  bool markedRead = false;

  ResponseBody _json(Object body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
  );

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    switch ((o.method, o.path)) {
      case ('GET', '/v1/notifications'):
        final now = DateTime.now().toUtc();
        return _json({
          'data': [
            {
              'id': 'n1',
              'type': 'payment.failed',
              'title': 'Pembayaran gagal',
              'body': 'Pembayaran INV-1 gagal dan tidak ada dana yang terpotong.',
              'deep_link': 'onelotus://pasien/paket',
              'created_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
            },
            {
              'id': 'n2',
              'type': 'booking.accepted',
              'title': 'Booking dikonfirmasi',
              'body': 'Jadwal terapi Anda sudah terkonfirmasi.',
              'deep_link': 'onelotus://pasien/jadwal',
              'created_at': now.subtract(const Duration(days: 3)).toIso8601String(),
              'read_at': now.subtract(const Duration(days: 2)).toIso8601String(),
            },
          ],
          'page': {'has_more': false},
        });
      case ('POST', '/v1/notifications/read-all'):
        markedRead = true;
        return _json({'data': {}});
      case ('GET', '/v1/patient/consent'):
        return _json({'data': {'reminders': true, 'promo': false}});
    }
    return _json({'data': []});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('tautan notifikasi → rute pasien yang dikenal saja', () {
    expect(pasienRouteForLink('onelotus://pasien/jadwal'), '/pasien/jadwal');
    expect(pasienRouteForLink('onelotus://pasien/struk?id=r1'), '/pasien/struk?id=r1');
    expect(pasienRouteForLink('onelotus://pasien/latihan'), '/pasien/latihan');
    expect(pasienRouteForLink('onelotus://invoices/abc'), isNull); // tautan staf
    expect(pasienRouteForLink('onelotus://pasien/tidak-ada'), isNull);
    expect(pasienRouteForLink(null), isNull);
  });

  testWidgets('daftar dikelompokkan Baru / Sebelumnya, lalu ditandai sudah dibaca', (tester) async {
    final server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = server;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pasienApiProvider.overrideWith(
            (ref) => PasienApi(ApiClient(baseUrl: 'http://uji', token: () => 'a', dio: dio), deviceId: () async => 'hp'),
          ),
        ],
        child: TestApp(scroll: false, child: const NotifikasiPasienPage()),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Baru'), findsOneWidget);
    expect(find.text('Sebelumnya'), findsOneWidget);
    expect(find.text('Pembayaran gagal'), findsOneWidget);
    expect(find.text('5 mnt lalu'), findsOneWidget);
    expect(find.text('Booking dikonfirmasi'), findsOneWidget);
    expect(server.markedRead, isTrue);
  });
}
