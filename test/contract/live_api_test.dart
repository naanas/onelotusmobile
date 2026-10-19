// Tes kontrak klien aplikasi ↔ One Lotus API v1 sungguhan (backend Go). Dilewati kecuali dijalankan dengan:
//   flutter test test/contract --dart-define=LIVE_API=http://localhost:8080 \
//     --dart-define=OWNER=demo.owner --dart-define=THERAPIST=demo.terapis --dart-define=PASSWORD=Sip123456
// Butuh database uji hasil migrasi 007–010 (+ data Laravel): satu cabang aktif, layanan, terapis [THERAPIST]
// di cabang itu, dan akun [OWNER] dengan peran owner + kasir. Tes membuat jadwal besok lalu membatalkannya.
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/api/one_lotus_api.dart';
import 'package:onelotus_staff/data/auth/api_auth_repository.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/data/remote/http_remote.dart';
import 'package:onelotus_staff/data/sync/outbox.dart';
import 'package:onelotus_staff/data/sync/sync_engine.dart';
import 'package:onelotus_staff/data/remote/remote.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

const _base = String.fromEnvironment('LIVE_API');
const _owner = String.fromEnvironment('OWNER', defaultValue: 'demo.owner');
const _therapist = String.fromEnvironment('THERAPIST', defaultValue: 'demo.terapis');
const _password = String.fromEnvironment('PASSWORD', defaultValue: 'Sip123456');

class _Login {
  _Login(this.client, this.user);
  final ApiClient client;
  final StaffUser user;
  OneLotusApi get api => OneLotusApi(client, me: () => user);
}

Future<_Login> _login(String username) async {
  String? token;
  String? branch;
  final client = ApiClient(
    baseUrl: _base,
    token: () => token,
    deviceId: () => 'tes-kontrak-$username',
    branchId: () => branch,
  );
  final r = await ApiAuthRepository(client, deviceId: () async => 'tes-kontrak-$username')
      .login(username, _password);
  token = r.token;
  branch = r.user.branches.first.id;
  return _Login(client, r.user);
}

DateTime _nextWorkday() {
  var d = DateTime.now().add(const Duration(days: 1));
  if (d.weekday == DateTime.sunday) d = d.add(const Duration(days: 1));
  return DateTime(d.year, d.month, d.day);
}

void main() {
  test(
    'kontrak API v1 langsung',
    () async {
      final owner = await _login(_owner);
      final terapis = await _login(_therapist);
      expect(owner.user.roles, containsAll([Role.owner, Role.kasir]));
      expect(terapis.user.roles, contains(Role.terapis));
      final branchId = owner.user.branches.first.id;
      final api = owner.api;
      final day = _nextWorkday();

      // Data pendukung jadwal.
      final branch = await api.branch(branchId);
      expect(branch.openingHours, isNotEmpty);
      final ts = await api.therapists(branchId);
      final me = ts.where((t) => t.id == terapis.user.id).single;
      final svc = (await api.services(branchId)).first;
      final slots = await api.slots(branchId: branchId, date: day, serviceId: svc.id, therapistId: me.id);
      final free = slots.where((s) => s.available).toList();
      expect(free, isNotEmpty);

      // Pasien: daftar berkursor, cari nomor, detail.
      final page1 = await api.patients();
      expect(page1.items, hasLength(20));
      expect(page1.hasMore, isTrue);
      final page2 = await api.patients(page: 2);
      expect(page2.items.first.id, isNot(page1.items.first.id));
      final target = page1.items.first;
      final found = await api.patients(query: '#${target.number}');
      expect(found.items.map((p) => p.id), contains(target.id));
      final detail = await api.patient(target.id);
      expect(detail.number, target.number);

      // Jadwal → hadir (kasir) → mulai & rekam & selesai (terapis lewat outbox sender).
      final session = await api.createSession(
        patientId: target.id,
        serviceId: svc.id,
        branchId: branchId,
        therapistId: me.id,
        startAt: free.first.startAt,
      );
      expect(session.status, SessionStatus.scheduled);
      expect(session.therapistId, me.id);
      await expectLater(
        api.createSession(
          patientId: target.id,
          serviceId: svc.id,
          branchId: branchId,
          therapistId: me.id,
          startAt: free.first.startAt,
        ),
        throwsA(isA<AppError>().having((e) => e.apiCode, 'code', 'slot_unavailable')),
      );
      final daySessions = await HttpRemote(terapis.client).sessions(
        branchId: branchId,
        from: day,
        to: day.add(const Duration(days: 1)),
        therapistId: me.id,
      );
      expect(daySessions.map((s) => s.id), contains(session.id));

      // Terapis belum boleh mulai sebelum pasien datang.
      final sender = ApiOutboxSender(terapis.client);
      OutboxItem item(String kind, String entity, Map<String, dynamic> p, {int base = 0}) => OutboxItem(
        id: newId(),
        kind: kind,
        entityId: entity,
        payload: p,
        baseVersion: base,
        createdAt: DateTime.now(),
        nextAttemptAt: DateTime.now(),
      );
      final early = await sender.send(item(OutboxKinds.sessionStatus, session.id, {'status': 'running'}));
      expect(early, isA<SendError>());

      // Batalkan (kasir) agar data uji bersih.
      final cancelled = await api.setStatus(session.id, SessionStatus.cancelled, reason: 'tes kontrak');
      expect(cancelled.status, SessionStatus.cancelled);

      // Persetujuan owner dapat dibaca.
      await api.leaves(status: 'pending');
      await api.passwordResets();

      // Catatan lama: kasir tanpa records.read_full ditolak; owner boleh.
      await api.legacyRecords(target.id);
    },
    skip: _base.isEmpty ? 'set --dart-define=LIVE_API=... untuk menjalankan' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
