// Tes lampiran terenkripsi memakai klien aplikasi ke backend sungguhan. Dilewati kecuali:
//   flutter test test/contract/lampiran_live_test.dart --dart-define=LIVE_API=http://localhost:58091
// Backend butuh SUPABASE_SERVICE_ROLE_KEY + FILE_ENCRYPTION_KEY. Membuat lampiran di profil pasien pertama.
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/api/billing_api.dart';
import 'package:onelotus_staff/data/auth/api_auth_repository.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

const _base = String.fromEnvironment('LIVE_API');
const _owner = String.fromEnvironment('OWNER', defaultValue: 'demo.semua');
const _cashier = String.fromEnvironment('CASHIER', defaultValue: 'demo.kasir');
const _password = String.fromEnvironment('PASSWORD', defaultValue: 'Sip123456');

Future<ApiClient> _login(String username) async {
  String? token;
  String? branch;
  final client = ApiClient(
    baseUrl: _base,
    token: () => token,
    deviceId: () => 'uji-$username',
    branchId: () => branch,
  );
  final r = await ApiAuthRepository(
    client,
    deviceId: () async => 'uji-$username',
  ).login(username, _password);
  token = r.token;
  branch = r.user.branches.first.id;
  return client;
}

void main() {
  final skip = _base.isEmpty ? 'set --dart-define=LIVE_API=...' : false;

  test(
    'rontgen: unggah → unduh sama persis; kasir ditolak; isi palsu ditolak',
    () async {
      final owner = await _login(_owner);
      final billing = BillingApi(owner);
      final patients = await owner.get(
        '/v1/patients',
        (d) => d as List,
        query: {'limit': 1},
      );
      final patientId = (patients.first as Map)['id'].toString();

      final png = List<int>.generate(4096, (i) => i * 7 % 256)
        ..setRange(0, 8, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final id = await billing.upload(
        ownerType: 'patient',
        ownerId: patientId,
        kind: 'xray',
        mime: 'image/png',
        bytes: png,
      );
      expect(await billing.attachment(id), png);

      // Kasir tanpa izin rontgen: 403, pesan terbaca walau respons diminta sebagai byte.
      final kasir = BillingApi(await _login(_cashier));
      await expectLater(
        kasir.attachment(id),
        throwsA(
          isA<AppError>().having((e) => e.type, 'type', ErrorCode.forbidden),
        ),
      );

      await expectLater(
        billing.upload(
          ownerType: 'patient',
          ownerId: patientId,
          kind: 'photo',
          mime: 'image/jpeg',
          bytes: '<html></html>'.codeUnits,
        ),
        throwsA(
          isA<AppError>().having(
            (e) => e.fieldErrors['mime'],
            'mime',
            isNotNull,
          ),
        ),
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
