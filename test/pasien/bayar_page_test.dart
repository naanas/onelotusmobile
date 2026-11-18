import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/pasien/pasien_api.dart';
import 'package:onelotus_staff/pasien/booking/bayar_page.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';
import 'package:onelotus_staff/theme/app_theme.dart';

/// Server palsu: satu tagihan Rp150.000; bayar VA BCA → nomor VA dari gateway.
class _Server implements HttpClientAdapter {
  _Server({this.existingVa = false});

  /// Tagihan sudah punya VA aktif (dibuat sebelumnya).
  final bool existingVa;
  final paid = <Map<String, dynamic>>[];

  ResponseBody _json(int code, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    code,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
  );

  static const _invoice = {
    'id': 'i1',
    'number': 'INV-0001',
    'status': 'unpaid',
    'patient': {'id': 'p1', 'name': 'Pasien Uji', 'number': 1},
    'items': [
      {'kind': 'service', 'description': 'Terapi Uji', 'qty': 1, 'unit_price': 150000, 'amount': 150000},
    ],
    'breakdown': {'subtotal': 150000, 'total': 150000, 'paid': 0, 'balance': 150000},
  };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    switch ((o.method, o.path)) {
      case ('GET', '/v1/patient/invoices'):
        return _json(200, {
          'data': [
            {
              ..._invoice,
              if (existingVa) ...{
                'status': 'awaiting_payment',
                'payments': [
                  {
                    'id': 'y0',
                    'method': 'va',
                    'amount': 150000,
                    'status': 'pending',
                    'va_bank': 'bca',
                    'va_number': '8808999900001111',
                    'expires_at': DateTime.now().add(const Duration(hours: 5)).toUtc().toIso8601String(),
                  },
                ],
              },
            },
          ],
        });
      case ('GET', '/v1/patient/payment-channels'):
        return _json(200, {
          'data': [
            {'method': 'va', 'va_bank': 'bca', 'code': 'BCAVA', 'label': 'BCA Virtual Account', 'fee': 4250, 'total': 154250},
          ],
        });
      case ('POST', '/v1/patient/invoices/i1/pay'):
        paid.add((o.data as Map).cast<String, dynamic>());
        return _json(201, {
          'data': {
            'payment': {
              'id': 'y1',
              'method': 'va',
              'amount': 150000,
              'status': 'pending',
              'va_bank': 'bca',
              'va_number': '8808123456789012',
              'expires_at': DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
            },
            'invoice': {..._invoice, 'status': 'awaiting_payment'},
          },
        });
    }
    return _json(404, {'error': {'code': 'not_found', 'message': '${o.method} ${o.path}'}});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('dari booking (VA BCA): instruksi VA langsung tampil + nota kertas, tanpa tab & tombol bayar', (tester) async {
    final server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = server;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pasienApiProvider.overrideWith(
            (ref) => PasienApi(ApiClient(baseUrl: 'http://uji', token: () => 'a', dio: dio), deviceId: () async => 'hp'),
          ),
        ],
        child: MaterialApp(
          theme: buildOlTheme(),
          home: const BayarPage(invoiceId: 'i1', initialMethod: 'va', initialBank: 'bca', autoStart: true),
        ),
      ),
    );

    // Memuat: animasi, bukan skeleton.
    expect(find.text('Memuat rincian tagihan'), findsOneWidget);
    expect(find.text('Pembayaran'), findsNothing);
    expect(find.bySemanticsLabel('Kembali'), findsNothing);

    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(server.paid.single['method'], 'va');
    expect(server.paid.single['va_bank'], 'bca');
    expect(find.text('8808 1234 5678 9012'), findsOneWidget);
    expect(find.text('BCA Virtual Account'), findsOneWidget);
    expect(find.text('Menunggu pembayaran'), findsOneWidget);
    // Nota kertas: total = tagihan + biaya admin kanal.
    expect(find.text('ONE LOTUS'), findsOneWidget);
    expect(find.text('Rp154.250'), findsOneWidget);
    // Tidak ada tab metode / tombol bayar.
    expect(find.text('Virtual account'), findsNothing);
    expect(find.textContaining('Bayar Rp'), findsNothing);
    expect(find.textContaining('Geser untuk bayar'), findsNothing);
    // Instruksi bayar: tombol kembali ada (→ Beranda + notif menunggu); "Selesai" hanya di struk.
    expect(find.bySemanticsLabel('Kembali'), findsOneWidget);
    expect(find.text('Selesai'), findsNothing);
  });

  testWidgets('geser bayar: layar bayar langsung terbuka, booking dibuat di sini dengan animasi', (tester) async {
    final server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = server;
    final booking = Completer<String?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pasienApiProvider.overrideWith(
            (ref) => PasienApi(ApiClient(baseUrl: 'http://uji', token: () => 'a', dio: dio), deviceId: () async => 'hp'),
          ),
        ],
        child: MaterialApp(
          theme: buildOlTheme(),
          home: BayarPage(initialMethod: 'va', initialBank: 'bca', autoStart: true, prepare: booking.future),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Memproses booking Anda'), findsOneWidget);
    expect(find.text('Pembayaran'), findsNothing);
    expect(find.bySemanticsLabel('Kembali'), findsNothing);
    expect(server.paid, isEmpty);

    booking.complete('i1');
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(server.paid.single['va_bank'], 'bca');
    expect(find.text('8808 1234 5678 9012'), findsOneWidget);
  });

  testWidgets('dibuka dari Profil: VA yang sudah terbit langsung tampil, tanpa membuat tagihan baru', (tester) async {
    final server = _Server(existingVa: true);
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = server;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pasienApiProvider.overrideWith(
            (ref) => PasienApi(ApiClient(baseUrl: 'http://uji', token: () => 'a', dio: dio), deviceId: () async => 'hp'),
          ),
        ],
        child: MaterialApp(theme: buildOlTheme(), home: const BayarPage(invoiceId: 'i1')),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('8808 9999 0000 1111'), findsOneWidget);
    expect(server.paid, isEmpty);
    expect(find.textContaining('Geser untuk bayar'), findsNothing);
    expect(find.bySemanticsLabel('Kembali'), findsOneWidget);
  });
}
