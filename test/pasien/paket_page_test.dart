import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/data/pasien/pasien_api.dart';
import 'package:onelotus_staff/data/pasien/pasien_app_api.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';
import 'package:onelotus_staff/pasien/profil/paket_page.dart';

import '../helpers.dart';

Map<String, dynamic> _inv(String id, String status, {List<Map<String, dynamic>> payments = const [], int balance = 150000, String kind = 'session'}) => {
  'id': id,
  'number': 'INV-$id',
  'kind': kind,
  'status': status,
  'items': [
    {'kind': kind == 'package' ? 'package' : 'service', 'description': kind == 'package' ? 'Paket 5 Sesi' : 'Terapi', 'qty': 1, 'unit_price': 150000, 'amount': 150000},
  ],
  'payments': payments,
  'breakdown': {'subtotal': 150000, 'total': 150000, 'paid': 150000 - balance, 'balance': balance},
  if (status == 'paid') 'receipt_id': 'r-$id',
};

Map<String, dynamic> _pay(String id, String status, {DateTime? expires}) => {
  'id': id,
  'method': 'qris',
  'amount': 150000,
  'status': status,
  'created_at': DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String(),
  if (expires != null) 'expires_at': expires.toUtc().toIso8601String(),
};

/// Server palsu: satu paket aktif, tagihan gagal (callback FAILED), tagihan menunggu, tagihan lunas.
class _Server implements HttpClientAdapter {
  int invoiceCalls = 0;

  ResponseBody _json(Object body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
  );

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    switch (o.path) {
      case '/v1/patient/packages':
        return _json({
          'data': [
            {'id': 'o1', 'package': {'name': 'Paket 5 Sesi'}, 'remaining': 3, 'sessions_total': 5, 'status': 'active', 'expires_on': '2099-01-01'},
          ],
        });
      case '/v1/patient/invoices':
        invoiceCalls++;
        return _json({
          'data': [
            _inv('gagal', 'unpaid', payments: [_pay('y1', 'failed')]),
            _inv('tunggu', 'awaiting_payment', payments: [_pay('y2', 'pending', expires: DateTime.now().add(const Duration(hours: 2)))]),
            _inv('lunas', 'paid', balance: 0, kind: 'package', payments: [_pay('y3', 'succeeded')]),
          ],
        });
    }
    return _json({'data': []});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('InvoiceV.payState mengikuti hasil gateway', () {
    InvoiceV inv(String status, List<Map<String, dynamic>> pays) => InvoiceV.fromJson(_inv('x', status, payments: pays));

    test('callback gagal → failed (bukan sekadar "belum dibayar")', () {
      expect(inv('unpaid', [_pay('a', 'failed')]).payState, InvoicePayState.failed);
    });
    test('percobaan terakhir yang menentukan', () {
      expect(inv('unpaid', [_pay('a', 'failed'), _pay('b', 'expired')]).payState, InvoicePayState.expired);
    });
    test('kode bayar masih berlaku → menunggu; lewat waktu → kedaluwarsa', () {
      final later = DateTime.now().add(const Duration(hours: 1));
      final past = DateTime.now().subtract(const Duration(minutes: 1));
      expect(inv('awaiting_payment', [_pay('a', 'pending', expires: later)]).payState, InvoicePayState.waiting);
      expect(inv('awaiting_payment', [_pay('a', 'pending', expires: past)]).payState, InvoicePayState.expired);
    });
    test('tanpa percobaan → belum dibayar; lunas → lunas', () {
      expect(inv('unpaid', []).payState, InvoicePayState.unpaid);
      expect(inv('paid', [_pay('a', 'succeeded')]).payState, InvoicePayState.paid);
    });
  });

  testWidgets('paket aktif, status pembayaran (gagal/menunggu), riwayat; cache tampil tanpa skeleton', (tester) async {
    final server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = server;
    final container = ProviderContainer(
      overrides: [
        pasienApiProvider.overrideWith(
          (ref) => PasienApi(ApiClient(baseUrl: 'http://uji', token: () => 'a', dio: dio), deviceId: () async => 'hp'),
        ),
      ],
    );
    addTearDown(container.dispose);
    Future<void> open() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(key: UniqueKey(), scroll: false, child: const PaketPage()),
        ),
      );
    }

    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    await open();
    await settle();

    expect(find.text('Paket aktif'), findsOneWidget);
    expect(find.text('dari 5 sesi tersisa'), findsOneWidget);
    // Tab status tampil lebih dulu (ada tagihan terbuka); riwayat di tab sebelahnya.
    expect(find.text('Status pembayaran (2)'), findsOneWidget);
    expect(find.text('Pembayaran gagal'), findsOneWidget);
    expect(find.text('Menunggu pembayaran'), findsOneWidget);
    expect(find.text('Lunas'), findsNothing);
    await tester.tap(find.text('Riwayat pembelian'));
    await settle();
    expect(find.text('Lunas'), findsOneWidget);
    expect(find.text('Pembayaran gagal'), findsNothing);
    await tester.tap(find.text('Status pembayaran (2)'));
    await settle();

    // Ketuk tagihan gagal → rincian menyebut gagal, aksinya "Bayar lagi".
    await tester.tap(find.text('Pembayaran gagal'));
    await settle();
    expect(find.textContaining('Pembayaran terakhir gagal'), findsOneWidget);
    expect(find.text('Bayar lagi'), findsOneWidget);
    expect(find.text('Gagal'), findsOneWidget); // riwayat percobaan bayar

    // Buka lagi: data dari cache langsung tampil (tanpa menunggu server).
    expect(container.read(pasienAppApiProvider).cached<List<InvoiceV>>('invoices'), isNotNull);
    await open();
    await tester.pump();
    expect(find.text('Paket aktif'), findsOneWidget);
    await settle();
  });
}
