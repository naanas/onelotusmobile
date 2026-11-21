// Tes kontrak ke backend sungguhan (hanya membaca data, lalu logout).
//   flutter test test/contract/live_api_test.dart \
//     --dart-define=LIVE_API=http://localhost:8080 --dart-define=USERNAME=... --dart-define=PASSWORD=...
// Tanpa LIVE_API tes dilewati.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/data/api_client.dart';
import 'package:onelotus_staff/data/klinik_api.dart';
import 'package:onelotus_staff/data/models.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

const _url = String.fromEnvironment('LIVE_API');
const _user = String.fromEnvironment('USERNAME');
const _pass = String.fromEnvironment('PASSWORD');

void main() {
  String? token;
  final client = ApiClient(
    baseUrl: _url,
    token: () => token,
    dio: Dio(
      BaseOptions(baseUrl: _url, receiveTimeout: const Duration(seconds: 60)),
    ),
  );
  final api = KlinikApi(client);

  setUpAll(() => initializeDateFormatting('id'));

  test(
    'kontrak API live',
    () async {
      final login = await client.post('/v1/login', {
        'username': _user,
        'password': _pass,
        'device_name': 'tes kontrak',
      }, (d) => (d as Map).cast<String, dynamic>());
      token = login['token'] as String;
      final me = AppUser.fromJson((login['user'] as Map).cast());
      expect(me.username, _user);

      final page = await api.pasien(perPage: 5);
      expect(page.items, isNotEmpty);
      expect(page.total, greaterThan(0));
      final p = page.items.first;
      expect(p.nama, isNotEmpty);
      expect(p.ttl, isNotNull);
      if (me.isAdmin) expect(p.tlp, isNotNull);

      final cari = await api.pasien(cari: p.nama.split(' ').first);
      expect(cari.items.any((x) => x.id == p.id), isTrue);

      final withExam = (await api.pasien(
        perPage: 100,
      )).items.firstWhere((x) => x.jumlahPemeriksaan > 0);
      final d = await api.detail(withExam.id);
      expect(d.pasien.id, withExam.id);
      expect(d.perawatan, isNotEmpty);
      expect(d.perawatan.first.pasienId, withExam.id);
      final x = await api.perawatan(d.perawatan.first.id);
      expect(x.id, d.perawatan.first.id);

      final bulan = d.perawatan.first.tanggal!;
      final rekap = await api.rekap(DateTime(bulan.year, bulan.month));
      expect(rekap.any((r) => r.perawatanId == x.id), isTrue);

      final xlsx = await api.export(DateTime(bulan.year, bulan.month));
      expect(String.fromCharCodes(xlsx.take(2)), 'PK');
      await expectLater(
        api.export(DateTime(2001)),
        throwsA(
          isA<AppError>().having((e) => e.type, 'type', ErrorCode.notFound),
        ),
      );

      await api.formulir();
      if (me.isAdmin) {
        final users = await api.users();
        expect(users.any((u) => u.username == _user), isTrue);
      }

      await client.post('/v1/logout', null, (_) {});
      await expectLater(
        client.get('/v1/me', (d) => d),
        throwsA(
          isA<AppError>().having((e) => e.type, 'type', ErrorCode.authExpired),
        ),
      );
    },
    skip: _url.isEmpty ? 'Set --dart-define=LIVE_API=...' : false,
  );
}
