import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/auth/session_store.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/data/pasien/pasien_api.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';

/// Server palsu: akun baru belum terhubung ke data pasien sampai `POST /v1/patient/register`.
class _FakeServer implements HttpClientAdapter {
  bool linked = false;
  Map<String, dynamic>? registerBody;
  final consents = <Map<String, dynamic>>[];

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
  );

  Map<String, dynamic> get _profile => {
    'id': 'p1',
    'number': 7,
    'name': 'Pasien Uji',
    'phone': '+6281200000000',
    'consent': {'health_data': true, 'reminders': true, 'promo': true, 'policy_version': 'app'},
  };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final body = o.data is Map ? (o.data as Map).cast<String, dynamic>() : const <String, dynamic>{};
    switch ((o.method, o.path)) {
      case ('POST', '/v1/auth/patient/register'):
        return _json(201, {
          'data': {'tokens': {'access_token': 'a', 'refresh_token': 'r'}, 'link_status': 'not_found', 'candidates': []},
        });
      case ('GET', '/v1/patient/profile'):
        return linked
            ? _json(200, {'data': _profile})
            : _json(409, {
                'error': {'code': 'conflict', 'message': 'Hubungkan akun dulu.', 'details': {'reason': 'not_linked'}},
              });
      case ('POST', '/v1/patient/register'):
        registerBody = body;
        linked = true;
        return _json(201, {'data': _profile});
      case ('POST', '/v1/patient/consent'):
        consents.add(body);
        return _json(201, {'data': {}});
    }
    return _json(404, {'error': {'code': 'not_found', 'message': '${o.method} ${o.path}'}});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('daftar: buat password → persetujuan → isi data diri → beranda; persetujuan ikut terkirim', () async {
    final server = _FakeServer();
    final dio = Dio(BaseOptions(baseUrl: 'http://uji'))..httpClientAdapter = server;
    final store = MemorySessionStore();
    final c = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        pasienApiProvider.overrideWith(
          (ref) => PasienApi(ApiClient(baseUrl: 'http://uji', token: () => 'a', dio: dio), deviceId: () async => 'hp'),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.read(pasienSessionProvider);
    await Future<void>.delayed(Duration.zero); // _restore
    final session = c.read(pasienSessionProvider.notifier);

    // 1. Kode terverifikasi + password → akun dibuat; langkah berikut PERSETUJUAN (bukan hubungkan data).
    await session.register('081200000000', 'token-verifikasi', 'rahasia123');
    expect(c.read(pasienSessionProvider).phase, PasienPhase.consent);

    // 2. Setuju (dengan promo) → belum ada data pasien: disimpan dulu, lanjut isi data diri.
    await session.consent(promo: true);
    expect(c.read(pasienSessionProvider).phase, PasienPhase.link);
    expect(server.consents, isEmpty);
    expect(await store.read(PasienKeys.consentDraft), 'promo');

    // 3. Isi data diri → persetujuan (termasuk promo) ikut terkirim → beranda.
    await session.registerPatient(
      PatientDraft(name: 'Pasien Uji', birthDate: DateTime(1990), gender: Gender.female, phone: '081200000000'),
    );
    expect(c.read(pasienSessionProvider).phase, PasienPhase.ready);
    final consent = server.registerBody!['consent'] as Map;
    expect(consent['health_data'], isTrue);
    expect(consent['promo'], isTrue);
    expect(await store.read(PasienKeys.consentDraft), isNull);
  });
}
