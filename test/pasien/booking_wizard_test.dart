import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/pasien/pasien_api.dart';
import 'package:onelotus_staff/pasien/booking/booking_page.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';
import 'package:onelotus_staff/theme/app_theme.dart';

/// Server palsu katalog booking: satu cabang, satu layanan, tanpa alamat & slot.
class _Catalog implements HttpClientAdapter {
  _Catalog({this.homeVisit = false});

  /// Katalog dengan layanan home visit + satu alamat tersimpan.
  final bool homeVisit;

  ResponseBody _json(Object body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
  );

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      switch (o.path) {
        '/v1/branches' => _json({'data': [{'id': 'b1', 'name': 'Klinik Uji', 'address': 'Jl. Uji 1'}]}),
        '/v1/patient/catalog' => _json({
          'data': {
            'services': [
              {'id': 's1', 'name': 'Terapi Uji', 'duration_min': 60, 'price': 150000},
              if (homeVisit)
                {'id': 's2', 'name': 'Terapi Rumah', 'duration_min': 60, 'price': 200000, 'home_visit_allowed': true},
            ],
            'packages': [],
          },
        }),
        '/v1/patient/addresses' => _json({
          'data': [
            if (homeVisit) {'id': 'a1', 'label': 'Rumah', 'address': 'Jl. Mawar 2', 'lat': 0, 'lng': 0},
          ],
        }),
        '/v1/slots' => _json({
          'data': [
            {
              'start': _slot.toUtc().toIso8601String(),
              'end': _slot.add(const Duration(hours: 1)).toUtc().toIso8601String(),
              'available': true,
            },
          ],
        }),
        '/v1/patient/payment-channels' => _json({
          'data': [
            if (o.queryParameters['code'] == null || o.queryParameters['code'] == 'QRIS')
              {'method': 'qris', 'code': 'QRIS', 'label': 'QRIS', 'fee': 875, 'total': 150875},
            if (o.queryParameters['code'] == null || o.queryParameters['code'] == 'BCAVA')
              {'method': 'va', 'va_bank': 'bca', 'code': 'BCAVA', 'label': 'BCA Virtual Account', 'fee': 4250, 'total': 154250},
          ],
        }),
        _ => _json({'data': []}),
      };

  /// Besok jam 10.00 (slot picker membuka besok secara default).
  static final _slot = () {
    final d = DateTime.now().add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day, 10);
  }();

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('booking: satu langkah per layar, tombol Lanjut/Kembali di bawah', (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = _Catalog();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pasienApiProvider.overrideWith(
            (ref) => PasienApi(ApiClient(baseUrl: 'http://uji', token: () => 'a', dio: dio), deviceId: () async => 'hp'),
          ),
        ],
        child: MaterialApp(theme: buildOlTheme(), home: const Scaffold(body: BookingPage())),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(); // tombol bawah dibangun ulang setelah data tiba (post-frame)
    }

    await settle();

    // Langkah 1: pilih tipe kunjungan dulu. Layanan uji tidak mendukung home visit → nonaktif.
    expect(find.text('Mau terapi di mana?'), findsOneWidget);
    expect(find.text('Belum tersedia di cabang ini'), findsOneWidget);
    expect(find.text('Lanjut · Layanan'), findsOneWidget);
    expect(find.text('Kembali'), findsNothing);

    // Datang ke klinik → otomatis ke daftar layanan.
    await tester.tap(find.text('Datang ke klinik'));
    await settle();
    expect(find.text('Pilih Layanan Terapi'), findsOneWidget);
    expect(find.text('Langkah 2/5'), findsOneWidget);

    // Pilih layanan → otomatis ke langkah keluhan.
    await tester.tap(find.text('Terapi Uji'));
    await settle();
    expect(find.text('Keluhan & Kondisi'), findsOneWidget);
    expect(find.text('Pilih Layanan Terapi'), findsNothing);

    // Lanjut tanpa keluhan → pesan wajib isi, tetap di langkah ini.
    await tester.tap(find.text('Lanjut · Jadwal'));
    await settle();
    expect(find.text('Ceritakan singkat keluhan yang Anda rasakan.'), findsOneWidget);
    expect(find.text('Keluhan & Kondisi'), findsOneWidget);

    // Isi keluhan → lanjut ke jadwal.
    await tester.enterText(find.byType(TextField).first, 'Nyeri lutut kanan');
    await tester.tap(find.text('Lanjut · Jadwal'));
    await settle();
    expect(find.text('Pilih Jadwal Terapi'), findsOneWidget);
    expect(find.text('Keluhan & Kondisi'), findsNothing);

    // Pilih jam → otomatis ke langkah bayar.
    await tester.ensureVisible(find.text('10.00'));
    await tester.pump();
    await tester.tap(find.text('10.00'));
    await settle();
    await settle();
    expect(find.text('Metode Pembayaran'), findsOneWidget);
    // Kanal pertama dipilih otomatis; biaya admin & total ikut.
    await settle();
    expect(find.text('Biaya admin Rp875'), findsOneWidget);
    expect(find.textContaining('Geser untuk bayar Rp150.875'), findsOneWidget);

    // Ganti ke BCA VA → biaya dihitung ulang dari server → total berubah.
    // Gulir ke tengah layar (tepi atas tertutup bar header yang melekat).
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(find.text('BCA Virtual Account')), alignment: .5),
    );
    await tester.pump();
    await tester.tap(find.text('BCA Virtual Account'));
    await settle();
    await settle();
    expect(find.textContaining('Geser untuk bayar Rp154.250'), findsOneWidget);

    // Kembali (ikon) → jadwal; kembali lagi → keluhan masih terisi.
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await settle();
    expect(find.text('Pilih tanggal'), findsOneWidget);
    await tester.tap(find.text('Kembali'));
    await settle();
    expect(find.text('Keluhan & Kondisi'), findsOneWidget);
    expect(find.text('Nyeri lutut kanan'), findsOneWidget);
  });

  testWidgets('home visit: alamat tunggal terpilih otomatis, layanan disaring ke yang mendukung home visit', (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = _Catalog(homeVisit: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pasienApiProvider.overrideWith(
            (ref) => PasienApi(ApiClient(baseUrl: 'http://uji', token: () => 'a', dio: dio), deviceId: () async => 'hp'),
          ),
        ],
        child: MaterialApp(theme: buildOlTheme(), home: const Scaffold(body: BookingPage())),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }

    await settle();
    expect(find.text('Terapis datang ke rumah Anda'), findsOneWidget);
    await tester.tap(find.text('Home Visit'));
    await settle();
    // Tetap di langkah tipe (alamat tampil), alamat satu-satunya sudah terpilih → Lanjut aktif.
    expect(find.text('Mau terapi di mana?'), findsOneWidget);
    expect(find.textContaining('Jl. Mawar 2'), findsOneWidget);
    await tester.tap(find.text('Lanjut · Layanan'));
    await settle();
    expect(find.text('Terapi Rumah'), findsOneWidget);
    expect(find.text('Terapi Uji'), findsNothing);
  });
}
