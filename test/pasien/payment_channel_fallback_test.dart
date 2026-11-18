import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/pasien/pasien_api.dart';
import 'package:onelotus_staff/data/pasien/pasien_app_api.dart';
import 'package:onelotus_staff/pasien/booking/payment_channel_picker.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';
import 'package:onelotus_staff/theme/app_theme.dart';
import 'package:onelotus_staff/ui/ui.dart';

/// Server lama: belum punya /v1/patient/payment-channels → 404.
class _OldServer implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(
        jsonEncode({'error': {'code': 'not_found', 'message': 'Alamat API tidak dikenal.'}}),
        404,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('endpoint kanal belum ada (404) → pilihan standar tetap tampil, QRIS terpilih', (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = _OldServer();
    PayChannelV? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pasienApiProvider.overrideWith(
            (ref) => PasienApi(ApiClient(baseUrl: 'http://uji', token: () => 'a', dio: dio), deviceId: () async => 'hp'),
          ),
        ],
        child: MaterialApp(
          theme: buildOlTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => PaymentChannelPicker(
                  amount: 250000,
                  value: picked,
                  onChanged: (ch) => setState(() => picked = ch),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SkeletonCard), findsNothing);

    expect(find.text('Metode pembayaran gagal dimuat.'), findsNothing);
    expect(find.text('BCA Virtual Account'), findsOneWidget);
    expect(find.text('OVO'), findsOneWidget);
    expect(picked?.method, 'qris');
  });
}
