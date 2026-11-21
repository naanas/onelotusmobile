import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/app.dart';

import 'support/fake_api.dart';

Future<void> pumpApp(
  WidgetTester tester,
  FakeApi api, {
  Map<String, String>? session,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: api.overrides(session: session),
      child: const OneLotusApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  final pasienList = {
    'GET /v1/pasien': (_) => (
      200,
      {
        'data': [pasienJson()],
        'meta': {'page': 1, 'per_page': 30, 'total': 1},
      },
    ),
  };

  testWidgets(
    'belum login → layar Masuk; password salah menampilkan pesan server',
    (tester) async {
      final api = FakeApi({
        'POST /v1/login': (_) => (
          401,
          {
            'error': {
              'code': 'auth_invalid',
              'message': 'Username atau password salah.',
            },
          },
        ),
      });
      await pumpApp(tester, api);
      expect(find.text('Masuk ke One Lotus'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'admin');
      await tester.enterText(find.byType(TextField).at(1), 'salah');
      await tester.tap(find.text('Masuk').last);
      await tester.pumpAndSettle();
      expect(find.text('Username atau password salah.'), findsOneWidget);
      final sent = api.log.last.data;
      final body = (sent is String ? jsonDecode(sent) : sent) as Map;
      expect(body['username'], 'admin');
    },
  );

  testWidgets(
    'login admin → tab Data Pasien dengan nomor HP, menu User Management ada',
    (tester) async {
      final api = FakeApi({
        'POST /v1/login': (_) => (
          200,
          {
            'data': {'token': '1|abc', 'user': userJson()},
          },
        ),
        'GET /v1/me': (_) => (200, {'data': userJson()}),
        ...pasienList,
      });
      await pumpApp(tester, api);
      await tester.enterText(find.byType(TextField).at(0), 'uji.admin');
      await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
      await tester.tap(find.text('Masuk').last);
      await tester.pumpAndSettle();

      expect(find.text('Data Pasien'), findsWidgets);
      expect(find.text('Pasien Uji'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
      expect(
        api.log.any((r) => r.headers['Authorization'] == 'Bearer 1|abc'),
        isTrue,
      );

      for (final tab in ['Rekap', 'Formulir', 'Lainnya']) {
        expect(find.text(tab), findsWidgets);
      }
      await tester.tap(find.text('Lainnya'));
      await tester.pumpAndSettle();
      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('Export Excel'), findsOneWidget);
    },
  );

  testWidgets('terapis: tanpa nomor HP & tanpa User Management', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /v1/me': (_) =>
          (200, {'data': userJson(role: 'user', name: 'Terapis Uji')}),
      'GET /v1/pasien': (_) => (
        200,
        {
          'data': [pasienJson(withTlp: false)],
          'meta': {'page': 1, 'per_page': 30, 'total': 1},
        },
      ),
    });
    await pumpApp(tester, api, session: savedSession(role: 'user'));
    expect(find.text('Pasien Uji'), findsOneWidget);
    expect(find.text('081234567890'), findsNothing);
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    expect(find.text('User Management'), findsNothing);
    expect(find.textContaining('Terapis'), findsWidgets);
  });

  testWidgets('detail pasien menampilkan data & pemeriksaan', (tester) async {
    final api = FakeApi({
      'GET /v1/me': (_) => (200, {'data': userJson()}),
      ...pasienList,
      'GET /v1/pasien/7': (_) => (
        200,
        {
          'data': {
            'pasien': pasienJson(),
            'perawatan': [
              {
                'id': 11,
                'data_pasien_id': 7,
                'keluhan': 'Nyeri lutut',
                'analisa': 'ACL',
                'terapis': 'Terapis Uji',
                'created_at': '2026-11-03 00:00:00',
              },
            ],
          },
        },
      ),
    });
    await pumpApp(tester, api, session: savedSession());
    await tester.tap(find.text('Pasien Uji'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Pasien'), findsOneWidget);
    expect(find.text('1362'), findsOneWidget);
    expect(find.text('Pemeriksaan (1)'), findsOneWidget);
    expect(find.text('03-11-2026'), findsOneWidget);
    expect(
      find.textContaining('Nyeri lutut', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('token ditolak server → kembali ke Masuk dengan pemberitahuan', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /v1/me': (_) => (
        401,
        {
          'error': {'message': 'Sesi berakhir. Silakan masuk lagi.'},
        },
      ),
      'GET /v1/pasien': (_) => (
        401,
        {
          'error': {'message': 'Sesi berakhir. Silakan masuk lagi.'},
        },
      ),
    });
    await pumpApp(tester, api, session: savedSession());
    expect(find.text('Masuk ke One Lotus'), findsOneWidget);
    expect(find.text('Sesi berakhir. Silakan masuk lagi.'), findsOneWidget);
  });

  testWidgets(
    'formulir: Tambah Pasien membuka Tambah Pemeriksaan terisi keluhan',
    (tester) async {
      final api = FakeApi({
        'GET /v1/me': (_) => (200, {'data': userJson()}),
        ...pasienList,
        'GET /v1/formulir': (_) => (
          200,
          {
            'data': [
              {
                'id': 3,
                'timestamp': '21/11/2026 09:00:00',
                'nama': 'Budi Form',
                'alamat': 'Malang',
                'tanggal_lahir': '1995-02-03',
                'jenis_kelamin': 'L',
                'keluhan': 'Nyeri bahu',
                'sudah_ditambahkan': false,
              },
            ],
          },
        ),
        'POST /v1/formulir/3/tambah-pasien': (_) => (
          201,
          {
            'data': {
              'pasien_id': 9,
              'keluhan': 'Nyeri bahu',
              'penyebab': 'Jatuh',
              'lama': '1 bulan',
              'rontgen': null,
            },
          },
        ),
      });
      await pumpApp(tester, api, session: savedSession());
      await tester.tap(find.text('Formulir'));
      await tester.pumpAndSettle();
      expect(find.text('1. Budi Form'), findsOneWidget);
      await tester.tap(find.text('Tambah Pasien'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah Pasien').last); // konfirmasi
      await tester.pumpAndSettle();
      expect(find.text('Tambah Pemeriksaan'), findsOneWidget);
      expect(find.text('Nyeri bahu'), findsOneWidget);
      expect(find.text('Jatuh'), findsOneWidget);
    },
  );
}
