// Tes kontrak klien aplikasi ↔ backend sungguhan. Dilewati kecuali dijalankan dengan:
//   flutter test test/contract --dart-define=LIVE_API=http://localhost:8080 \
//     --dart-define=OTP_LOG=/path/server.log
// Jalankan pada database uji yang baru diisi (alur pasien & cek ganda bergantung data awal).
// Membutuhkan database uji berisi data awal (cabang `mlg`, staf rudi.owner / sinta.kasir /
// dimas.terapis / laras.terapis dengan password `rahasia123`, layanan, pasien Andi #412 HP 0812-3456-7890).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/api/api_error_mapper.dart';
import 'package:onelotus_staff/data/api/one_lotus_api.dart';
import 'package:onelotus_staff/data/auth/api_auth_repository.dart';
import 'package:onelotus_staff/data/intake/intake_repository.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/data/pasien/pasien_api.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

const _base = String.fromEnvironment('LIVE_API');
const _otpLog = String.fromEnvironment('OTP_LOG');

Future<OneLotusApi> _staff(String username) async {
  String? token;
  final client = ApiClient(baseUrl: _base, token: () => token);
  final r = await ApiAuthRepository(client).login(username, 'rahasia123');
  token = r.token;
  return OneLotusApi(client);
}

DateTime _nextWorkday() {
  var d = DateTime.now().add(const Duration(days: 1));
  if (d.weekday == DateTime.sunday) d = d.add(const Duration(days: 1));
  return DateTime(d.year, d.month, d.day);
}

void main() {
  test(
    'kontrak API langsung',
    () async {
      final kasir = await _staff('sinta.kasir');
      final dimas = await _staff('dimas.terapis');
      final day = _nextWorkday();

      // Data pendukung jadwal
      final ts = await kasir.therapists('mlg', date: day);
      expect(
        ts.map((t) => t.name),
        containsAll(['Dimas Terapis', 'Laras Terapis']),
      );
      expect((await kasir.rooms('mlg')).length, greaterThanOrEqualTo(2));
      final branch = await kasir.branch('mlg');
      expect(branch.openingHours['1'], ['08:00', '20:00']);
      final svc = (await kasir.services('mlg')).single;
      final slots = await kasir.slots(
        branchId: 'mlg',
        date: day,
        serviceId: svc.id,
      );
      expect(slots.where((s) => s.available), isNotEmpty);

      // Pasien
      final page = await kasir.patients(query: 'Andi');
      final andi = page.items.single;
      expect(andi.number, 412);
      // Catatan lama Laravel: terapis & owner saja (§7); kasir ditolak.
      expect(
        (await dimas.legacyRecords(andi.id)).single.fields['Keluhan'],
        'Nyeri bahu',
      );
      await expectLater(
        kasir.legacyRecords(andi.id),
        throwsA(
          isA<AppError>().having((e) => e.type, 'type', ErrorCode.forbidden),
        ),
      );
      final detail = await dimas.patient(andi.id);
      expect(
        detail.phone,
        isNull,
        reason: 'telepon disaring server untuk terapis',
      );
    },
    skip: _base.isEmpty ? 'set --dart-define=LIVE_API' : false,
  );

  test(
    'alur kasir, terapis, owner, pasien',
    () async {
      final kasir = await _staff('sinta.kasir');
      final owner = await _staff('rudi.owner');
      final dimas = await _staff('dimas.terapis');
      final day = _nextWorkday();
      final svc = (await kasir.services('mlg')).single;
      final dimasId = (await kasir.therapists(
        'mlg',
      )).firstWhere((t) => t.name.startsWith('Dimas')).id;
      final lauraId = (await kasir.therapists(
        'mlg',
      )).firstWhere((t) => t.name.startsWith('Laras')).id;

      // KS-04 tambah pasien (repository intake/manual) + cek ganda
      final intakeRepo = HttpPatientIntakeRepository(kasir.api);
      final draft = PatientDraft(
        name: 'Kontrak Uji',
        birthDate: DateTime(1995, 3, 4),
        gender: Gender.female,
        phone: '0812 9999 0000',
        healthConsent: true,
      );
      final p = await intakeRepo.create(draft);
      expect(p.number, greaterThan(412));
      await expectLater(
        intakeRepo.create(draft),
        throwsA(isA<DuplicatePatientError>()),
      );
      final edited = await kasir.updatePatient(
        p.id,
        PatientDraft(
          name: 'Kontrak Uji Ubah',
          birthDate: DateTime(1995, 3, 4),
          gender: Gender.female,
          phone: '0812 9999 0000',
        ),
      );
      expect(edited.name, 'Kontrak Uji Ubah');

      // KS-06 buat jadwal + bentrok + walk-in + ubah + status
      final s1 = await kasir.createSession(
        patientId: p.id,
        serviceId: svc.id,
        branchId: 'mlg',
        therapistId: dimasId,
        startAt: day.add(const Duration(hours: 10)),
        room: 'Ruang 1',
      );
      expect(s1.status, SessionStatus.scheduled);
      try {
        await kasir.createSession(
          patientId: '1',
          serviceId: svc.id,
          branchId: 'mlg',
          therapistId: dimasId,
          startAt: day.add(const Duration(hours: 10, minutes: 30)),
        );
        fail('harus bentrok');
      } on AppError catch (e) {
        expect(e.type, ErrorCode.validation);
        expect(e.fieldError('start_at'), isNotNull);
      }
      final walk = await kasir.createSession(
        patientId: '2',
        serviceId: svc.id,
        branchId: 'mlg',
        therapistId: dimasId,
        walkIn: true,
      );
      expect(walk.status, SessionStatus.arrived);
      final moved = await kasir.updateSession(
        s1.id,
        startAt: day.add(const Duration(hours: 13)),
      );
      expect(moved.startAt.toLocal().hour, 13);
      expect((await kasir.session(s1.id)).id, s1.id);

      // TR: terapis memulai sesi walk-in miliknya (online), blok jam, cuti
      final running = await dimas.setStatus(walk.id, SessionStatus.running);
      expect(running.status, SessionStatus.running);
      final block = await dimas.createBlock(
        kind: 'once',
        startsAt: day.add(const Duration(hours: 16)),
        endsAt: day.add(const Duration(hours: 17)),
      );
      expect((await dimas.blocks()).map((b) => b.id), contains(block.id));
      await dimas.deleteBlock(block.id);
      final leave = await dimas.createLeave(
        startsAt: day.add(const Duration(days: 7)),
        endsAt: day.add(const Duration(days: 7)),
        allDay: true,
        reason: 'Keluarga',
      );
      expect(leave.status, LeaveStatus.pending);

      // KS-07/08 booking & pindah massal
      final moves = await kasir.bulkMove([
        (sessionId: s1.id, therapistId: lauraId, startAt: null),
      ]);
      expect(moves.single.status, 'moved');
      expect((await kasir.rescheduleRequests('mlg')), isEmpty);

      // OW-06 persetujuan, OW-08 staf, OW-17 cabang
      expect(
        (await owner.leaves(status: 'pending')).map((l) => l.id),
        contains(leave.id),
      );
      await owner.decideLeave(leave.id, approve: true);
      expect(await owner.passwordResets(), isEmpty);
      final staff = await owner.staff();
      expect(staff.length, greaterThanOrEqualTo(4));
      final (member, pw) = await owner.createStaff(
        name: 'Staf Kontrak',
        username:
            'staf.kontrak${DateTime.now().millisecondsSinceEpoch % 100000}',
        roles: const [Role.kasir],
        branchIds: const ['mlg'],
      );
      expect(pw.length, 10);
      expect(member.user.mustChangePassword, isTrue);
      await owner.updateStaff(
        member.user.id,
        name: 'Staf Kontrak',
        roles: const [Role.kasir, Role.terapis],
        branchIds: const ['mlg'],
      );
      expect((await owner.resetStaffPassword(member.user.id)).length, 10);
      await owner.revokeStaffTokens(member.user.id);
      await owner.setStaffActive(member.user.id, false);
      final b = await owner.branch('mlg');
      final updated = await owner.updateBranch(
        'mlg',
        name: b.branch.name,
        address: b.branch.address,
        openingHours: b.openingHours,
        waNumber: '081211112222',
      );
      expect(updated.waNumber, '081211112222');
      final room = await owner.saveRoom(
        'mlg',
        name: 'Ruang Kontrak ${DateTime.now().millisecondsSinceEpoch % 100000}',
      );
      expect(room.name, startsWith('Ruang Kontrak'));

      // Arsip & pulihkan
      await expectLater(
        kasir.archivePatient(p.id),
        throwsA(isA<AppError>()),
        reason: 'masih punya jadwal aktif',
      );
    },
    skip: _base.isEmpty ? 'set --dart-define=LIVE_API' : false,
  );

  test(
    'alur pasien (OTP → hubungkan → persetujuan → jadwal)',
    () async {
      String? token;
      final api = PasienApi(ApiClient(baseUrl: _base, token: () => token));
      const phone = '0812 3456 7890';
      await api.requestOtp(phone);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final code = File(_otpLog)
          .readAsLinesSync()
          .lastWhere((l) => l.contains('[otp-dev]'))
          .split(' ')
          .last;
      final (tok, acc) = await api.verifyOtp(phone, code);
      token = tok;
      expect(acc.nextStep, PasienNextStep.link);
      final cands = await api.linkCandidates();
      expect(cands.candidates.single.maskedName, 'An** Pr*****');
      try {
        await api.link(birthDate: DateTime(2000, 1, 1));
        fail('tanggal salah harus ditolak');
      } on AppError catch (e) {
        expect(e.fieldError('birth_date'), contains('Sisa'));
      }
      final linked = await api.link(
        patientId: cands.candidates.single.id,
        birthDate: DateTime(1999, 5, 12),
      );
      expect(linked.nextStep, PasienNextStep.consent);
      final ready = await api.consent(promo: false);
      expect(ready.nextStep, PasienNextStep.ready);
      expect((await api.me()).patient?.number, 412);
      await api.sessions();
      await api.sessions(past: true);
      await api.logout();
    },
    skip: _base.isEmpty || _otpLog.isEmpty
        ? 'set --dart-define=LIVE_API & OTP_LOG'
        : false,
  );
}
