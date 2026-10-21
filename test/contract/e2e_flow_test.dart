// Tes E2E lintas peran memakai klien API aplikasi sendiri (bukan mock) ke backend sungguhan.
// Dilewati kecuali dijalankan dengan:
//   flutter test test/contract/e2e_flow_test.dart \
//     --dart-define=LIVE_API=http://localhost:58091 --dart-define=OTP_LOG=/path/server.log \
//     --dart-define=OWNER=demo.semua --dart-define=THERAPIST=demo.terapis --dart-define=PATIENT_PHONE=081299990001
// Pasien masuk dengan nomor + password (PATIENT_PASSWORD); bila belum punya password tes mendaftar dulu lewat
// OTP, jadi backend harus jalan dengan MOBILE_OTP_DEV_LOG=true. Database harus database UJI:
// tes membuat booking, sesi, tagihan, pembayaran, paket, lalu membersihkan yang bisa dibatalkan.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/api/api_client.dart';
import 'package:onelotus_staff/data/api/billing_api.dart';
import 'package:onelotus_staff/data/api/one_lotus_api.dart';
import 'package:onelotus_staff/data/auth/api_auth_repository.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/data/pasien/pasien_api.dart';
import 'package:onelotus_staff/data/pasien/pasien_app_api.dart';
import 'package:onelotus_staff/data/remote/http_remote.dart';
import 'package:onelotus_staff/data/remote/remote.dart';
import 'package:onelotus_staff/data/sync/outbox.dart';
import 'package:onelotus_staff/data/sync/sync_engine.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

const _base = String.fromEnvironment('LIVE_API');
const _otpLog = String.fromEnvironment('OTP_LOG');
const _owner = String.fromEnvironment('OWNER', defaultValue: 'demo.semua');
const _therapist = String.fromEnvironment('THERAPIST', defaultValue: 'demo.terapis');
const _password = String.fromEnvironment('PASSWORD', defaultValue: 'Sip123456');
const _phone = String.fromEnvironment('PATIENT_PHONE', defaultValue: '081299990001');

class _Staff {
  _Staff(this.client, this.user);
  final ApiClient client;
  final StaffUser user;
  OneLotusApi get api => OneLotusApi(client, me: () => user);
  BillingApi get billing => BillingApi(client);
  String get branchId => user.branches.first.id;
}

Future<_Staff> _login(String username) async {
  String? token;
  String? branch;
  final client = ApiClient(baseUrl: _base, token: () => token, deviceId: () => 'e2e-$username', branchId: () => branch);
  final r = await ApiAuthRepository(client, deviceId: () async => 'e2e-$username').login(username, _password);
  token = r.token;
  branch = r.user.branches.first.id;
  return _Staff(client, r.user);
}

const _patientPassword = String.fromEnvironment('PATIENT_PASSWORD', defaultValue: 'E2E-rahasia1');

/// Login pasien lewat PasienApi (sama dengan aplikasi): nomor HP + password. Belum punya password →
/// daftar (kode OTP purpose=register dibaca dari log server) lalu masuk.
Future<PasienAppApi> _patient() async {
  String? token;
  final client = ApiClient(baseUrl: _base, token: () => token, deviceId: () => 'e2e-pasien');
  final pasien = PasienApi(client, deviceId: () async => 'e2e-pasien');
  (String, String, PasienAccount) session;
  try {
    session = await pasien.login(_phone, _patientPassword);
  } on AppError {
    final digits = _phone.replaceAll(RegExp(r'\D'), '');
    final tail = digits.substring(digits.length - 4);
    await pasien.requestOtp(_phone, purpose: 'register');
    String? code;
    for (var i = 0; i < 20 && code == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final lines = File(_otpLog).readAsStringSync().replaceAll('\u0000', '').split('\n').reversed;
      for (final l in lines) {
        if (l.contains('OTP pasien') && l.contains(tail) && l.contains('purpose=register')) {
          code = RegExp(r'code=(\d{6})').firstMatch(l)?.group(1);
          break;
        }
      }
    }
    expect(code, isNotNull, reason: 'kode OTP tidak ada di $_otpLog (MOBILE_OTP_DEV_LOG=true?)');
    final verification = await pasien.verifyCode(_phone, 'register', code!);
    session = await pasien.register(_phone, verification, _patientPassword);
  }
  final (access, _, account) = session;
  token = access;
  expect(account.patient, isNotNull, reason: 'nomor uji harus sudah terhubung ke data pasien');
  return PasienAppApi(client);
}

/// Bersihkan sisa putaran sebelumnya (database uji): booking aktif pasien uji & sesi terapis uji hari ini.
Future<void> _resetWith(_Staff owner, _Staff terapis, PasienAppApi pasien) async {
  for (final b in await pasien.bookings(scope: 'upcoming')) {
    if (const {'pending', 'proposed', 'accepted'}.contains(b.status)) {
      try {
        await pasien.cancelBooking(b.id, 'bersih E2E');
      } catch (_) {}
    }
  }
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final today = await owner.api.sessions(
    branchId: owner.branchId, from: day, to: day.add(const Duration(days: 1)), therapistId: terapis.user.id);
  final sender = ApiOutboxSender(terapis.client);
  for (final x in today) {
    if (x.status == SessionStatus.running) {
      // Sesi berjalan tidak bisa dibatalkan: lengkapi rekam lalu selesaikan.
      final area = ((await terapis.client.get('/v1/body-areas', (d) => d)) as List).first as Map;
      final rec = SessionRecord(
        id: newId(), sessionId: x.id, patientId: x.patientId, therapistId: terapis.user.id, complaint: 'bersih E2E',
        treatedAreas: ['${area['code']}:both'], painBefore: 1, painAfter: 1, treatments: const ['Adjustment'],
        updatedAt: DateTime.now());
      OutboxItem it(String kind, Map<String, dynamic> p) => OutboxItem(
        id: newId(), kind: kind, entityId: x.id, payload: p, baseVersion: 0,
        createdAt: DateTime.now(), nextAttemptAt: DateTime.now());
      await sender.send(it(OutboxKinds.sessionRecordUpsert, rec.toJson()));
      await sender.send(it(OutboxKinds.sessionStatus, {'status': 'done'}));
    } else if (const {SessionStatus.scheduled, SessionStatus.arrived}.contains(x.status)) {
      try {
        await owner.api.setStatus(x.id, SessionStatus.cancelled, reason: 'bersih E2E');
      } catch (_) {}
    }
  }
}

void main() {
  late _Staff owner, terapis;
  late PasienAppApi pasien;
  final cleanup = <Future<void> Function()>[];
  Future<void> reset() => _resetWith(owner, terapis, pasien);

  setUpAll(() async {
    if (_base.isEmpty) return;
    owner = await _login(_owner);
    terapis = await _login(_therapist);
    pasien = await _patient();
    await reset();
  });
  tearDownAll(() async {
    for (final f in cleanup.reversed) {
      try {
        await f();
      } catch (_) {}
    }
  });

  final skip = _base.isEmpty || _otpLog.isEmpty ? 'set --dart-define=LIVE_API=... dan OTP_LOG=...' : false;

  test('1. pasien booking → kasir melihat & menerima → sesi terbentuk → pasien melihat diterima', () async {
    final branches = await pasien.branches();
    final branchId = branches.firstWhere((b) => b.id == owner.branchId, orElse: () => branches.first).id;
    final svc = (await pasien.catalog(branchId: branchId)).services.firstWhere((s) => s.isActive);
    SlotV? slot;
    for (var d = 2; d < 9 && slot == null; d++) {
      final day = DateTime.now().add(Duration(days: d));
      final free = (await pasien.slots(branchId: branchId, serviceId: svc.id, date: day)).where((s) => s.available);
      if (free.isNotEmpty) slot = free.last;
    }
    expect(slot, isNotNull, reason: 'tidak ada slot kosong seminggu ke depan');

    final (booking, _) = await pasien.book({
      'branch_id': branchId,
      'service_id': svc.id,
      'location_type': 'clinic',
      'start': slot!.start.toUtc().toIso8601String(),
      'note': 'E2E',
    });
    expect(booking.status, 'pending');
    cleanup.add(() => pasien.cancelBooking(booking.id, 'bersih E2E').then((_) {}));

    // Kasir (layar Booking masuk) & counter Antrian memakai GET /v1/bookings?status=pending.
    final pending = await owner.billing.bookings(status: 'pending', branchId: branchId);
    final mine = pending.where((b) => b.id == booking.id).single;
    expect(mine.serviceId, svc.id);
    expect(mine.displayName, isNotEmpty);

    final accepted = await owner.billing.acceptBooking(booking.id);
    expect(accepted.status, 'accepted');
    final sessionId = (await owner.billing.bookings(status: 'accepted', branchId: branchId))
        .where((b) => b.id == booking.id)
        .single;
    expect(sessionId.status, 'accepted');

    // Sesi muncul di jadwal cabang.
    final day = DateTime(slot.start.toLocal().year, slot.start.toLocal().month, slot.start.toLocal().day);
    final sessions = await owner.api.sessions(branchId: branchId, from: day, to: day.add(const Duration(days: 1)));
    final s = sessions
        .where((x) => x.startAt.isAtSameMomentAs(slot!.start) && x.status != SessionStatus.cancelled)
        .toList();
    expect(s, isNotEmpty, reason: 'sesi dari booking tidak muncul di jadwal');
    cleanup.add(() => owner.api.setStatus(s.first.id, SessionStatus.cancelled, reason: 'bersih E2E').then((_) {}));

    // Pasien melihat booking diterima di Jadwal saya.
    final upcoming = await pasien.bookings();
    expect(upcoming.where((b) => b.id == booking.id).single.status, 'accepted');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('2. walk-in → terapis mulai, rekam, selesai → tagihan → bayar tunai → struk → pasien & komisi', () async {
    final branchId = owner.branchId;
    final me = (await owner.api.therapists(branchId)).where((t) => t.id == terapis.user.id).single;
    final svc = (await owner.api.services(branchId)).first;
    final target = (await owner.api.patients(query: _phone.substring(_phone.length - 4))).items.first;

    final walkIn = await owner.api.createSession(
      patientId: target.id,
      serviceId: svc.id,
      branchId: branchId,
      therapistId: me.id,
      walkIn: true,
    );
    expect(walkIn.status, anyOf(SessionStatus.arrived, SessionStatus.scheduled));

    // Terapis lewat outbox sender (jalur yang sama dengan aplikasi offline-first).
    final sender = ApiOutboxSender(terapis.client);
    OutboxItem item(String kind, Map<String, dynamic> p, {int base = 0}) => OutboxItem(
      id: newId(),
      kind: kind,
      entityId: walkIn.id,
      payload: p,
      baseVersion: base,
      createdAt: DateTime.now(),
      nextAttemptAt: DateTime.now(),
    );
    final started = await sender.send(item(OutboxKinds.sessionStatus, {'status': 'running'}));
    expect(started, isNot(isA<SendError>()), reason: 'mulai sesi: $started');

    final area = (await terapis.client.get('/v1/body-areas', (d) => d) as List).first as Map;
    final record = SessionRecord(
      id: newId(),
      sessionId: walkIn.id,
      patientId: target.id,
      therapistId: me.id,
      complaint: 'Nyeri punggung bawah (E2E)',
      treatedAreas: ['${area['code']}:both'],
      painBefore: 7,
      painAfter: 3,
      treatments: const ['Adjustment', 'Stretching'],
      conclusion: 'Latihan peregangan pagi.',
      updatedAt: DateTime.now(),
    );
    final saved = await sender.send(item(OutboxKinds.sessionRecordUpsert, record.toJson()));
    expect(saved, isNot(isA<SendError>()), reason: 'simpan rekam: $saved');
    final done = await sender.send(item(OutboxKinds.sessionStatus, {'status': 'done'}));
    expect(done, isNot(isA<SendError>()), reason: 'selesai sesi: $done');

    // Kasir: tagihan untuk sesi (draft dibuat otomatis) → terbitkan → bayar tunai → struk.
    var inv = await owner.billing.invoiceForSession(walkIn.id);
    expect(inv, isNotNull);
    if (inv!.status == 'draft') inv = await owner.billing.issue(inv.id);
    expect(inv.balance, greaterThan(0));
    final paid = await owner.billing.pay(inv.id, {'method': 'cash', 'amount': inv.balance, 'cash_received': inv.balance});
    expect(paid.invoice.status, 'paid');
    expect(paid.receipt, isNotNull);
    final receipt = await owner.billing.receipt(paid.receipt!.id);
    expect(receipt.items, isNotEmpty);

    // Pasien: tagihan lunas & riwayat sesi versi pasien (tanpa analisa internal).
    final pInv = (await pasien.invoices()).where((i) => i.id == inv!.id).single;
    expect(pInv.status, 'paid');
    final history = await pasien.sessions();
    final mine = history.where((h) => h.sessionId == walkIn.id).single;
    expect(mine.painBefore, 7);
    expect(mine.treatments, containsAll(['Adjustment', 'Stretching']));
    final pReceipt = await pasien.receipt(paid.receipt!.id);
    expect(pReceipt.number, receipt.number);

    // Terapis: komisi estimasi bulan ini tercatat.
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final comm = await terapis.billing.myCommissions(period: period);
    expect(comm.sessions, greaterThan(0));

    // Kasir: transaksi muncul di riwayat hari ini.
    final today = await owner.billing.invoices(status: 'paid', date: DateTime.now());
    expect(today.items.map((i) => i.id), contains(inv.id));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  test('3. owner buat paket → kasir jual & bayar → pasien melihat paket; laporan & persetujuan', () async {
    final svcIds = [for (final s in await owner.billing.catalogServices()) if (s.isActive) s.id];
    final pkg = await owner.billing.savePackage(null, {
      'name': 'Paket E2E ${DateTime.now().millisecondsSinceEpoch}',
      'service_ids': svcIds,
      'session_count': 3,
      'valid_days': 60,
      'price': 300000,
      'is_active': true,
    });
    final target = (await owner.api.patients(query: _phone.substring(_phone.length - 4))).items.first;
    var inv = await owner.billing.sellPackage(target.id, pkg.id);
    if (inv.status == 'draft') inv = await owner.billing.issue(inv.id);
    final paid = await owner.billing.pay(inv.id, {'method': 'cash', 'amount': inv.balance, 'cash_received': inv.balance});
    expect(paid.invoice.status, 'paid');

    final owned = await pasien.packages();
    expect(owned.map((o) => o.name), contains(pkg.name));
    final catalog = await pasien.catalog();
    expect(catalog.packages.map((p) => p.id), contains(pkg.id));
    cleanup.add(() => owner.billing.savePackage(pkg.id, {
      'name': pkg.name, 'session_count': 3, 'valid_days': 60, 'price': 300000, 'is_active': false, 'service_ids': svcIds,
    }).then((_) {}));

    // Owner: ringkasan laporan & daftar persetujuan bisa dibaca.
    final sum = await owner.billing.summary(from: DateTime.now().subtract(const Duration(days: 30)), to: DateTime.now());
    expect(sum.revenue, greaterThan(0));
    for (final t in ['refund', 'manual_discount', 'exercise_proposal', 'cash_difference']) {
      await owner.billing.approvals(t);
    }
    await owner.billing.notifications();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('4. owner: semua form pengaturan menyimpan dengan body yang sama seperti aplikasi', () async {
    final b = owner.billing;
    final u = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final today = DateTime.now();
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final services = await b.catalogServices();
    expect(services, isNotEmpty);

    // OW-12 voucher_page.dart
    final v = await b.saveVoucher(null, {
      'code': 'E2E$u', 'type': 'percent', 'value': 10, 'min_amount': 0, 'quota_total': null, 'quota_per_patient': null,
      'starts_at': DateTime(today.year, today.month, today.day).toUtc().toIso8601String(),
      'ends_at': DateTime(today.year, today.month, today.day + 30, 23, 59, 59).toUtc().toIso8601String(), 'is_active': true,
    });
    expect((await b.vouchers()).map((x) => x.id), contains(v.id));
    await b.saveVoucher(v.id, {
      'code': v.code, 'type': 'percent', 'value': 15, 'min_amount': 0, 'quota_total': 5, 'quota_per_patient': 1,
      'starts_at': v.startsAt.toUtc().toIso8601String(), 'ends_at': v.endsAt.toUtc().toIso8601String(), 'is_active': false,
    });

    // OW-11 aturan_komisi_page.dart
    final rule = await b.saveCommissionRule(null, {
      'scope': 'service', 'type': 'percent', 'value': 10, 'service_id': services.first.id, 'staff_id': null,
      'effective_from': day(today.add(const Duration(days: 365))),
    });
    expect((await b.commissionRules()).map((x) => x.id), contains(rule.id));

    // OW-16 pengumuman_page.dart
    final ann = await b.createAnnouncement({'title': 'E2E $u', 'body': 'Uji otomatis', 'roles': ['therapist', 'cashier']});
    expect(ann.title, 'E2E $u');

    // OW-14 template_page.dart
    final tpl = await b.saveTemplate(null, {
      'kind': 'wa_message', 'key': 'e2e_$u', 'title': 'E2E', 'content': {'body': 'Halo {nama}'}, 'variables': ['nama'],
      'is_active': true,
    });
    await b.saveTemplate(tpl.id, {
      'kind': 'wa_message', 'key': tpl.key, 'title': 'E2E ubah', 'content': {'body': 'Halo {nama}!'}, 'variables': ['nama'],
      'is_active': false,
    });

    // OW-15 pustaka_page.dart
    final area = ((await owner.client.get('/v1/body-areas', (d) => d)) as List).first as Map;
    final ex = await b.saveExercise(null, {
      'name': 'E2E latihan $u', 'level': 'easy', 'body_area_codes': [area['code']], 'steps': ['Langkah 1'],
      'default_sets': 3, 'default_reps': 10, 'default_duration_sec': null, 'video_url': null, 'warnings': null,
    });
    expect(ex.status, 'approved');
    await b.saveExercise(ex.id, {
      'name': ex.name, 'level': 'easy', 'body_area_codes': [area['code']], 'steps': ['Langkah 1'],
      'default_sets': 3, 'default_reps': 12, 'default_duration_sec': null, 'video_url': null, 'warnings': null, 'status': 'archived',
    });

    // OW-09 layanan_page.dart (ubah layanan yang ada tanpa mengubah harga)
    final sv = services.first;
    await b.saveService(sv.id, {
      'name': sv.name, 'duration_min': sv.durationMin, 'category': sv.category, 'price': sv.price,
      'member_price': sv.memberPrice, 'price_per_extra_point': sv.perExtraPoint, 'injury_surcharge': sv.injurySurcharge,
      'home_visit_allowed': sv.homeVisit, 'is_active': sv.isActive, 'version': ?sv.version, 'branch_ids': sv.branchIds,
    });

    // OW-13 poin_page.dart (simpan ulang nilai yang sama)
    final pr = await b.pointsRules();
    await b.savePointsRules(pr);

    // OW-07 rekap komisi & OW-04 laporan rincian
    await b.commissions(period: '${today.year}-${today.month.toString().padLeft(2, '0')}');
    for (final r in ['top_services', 'therapist_performance', 'retention', 'receivables', 'commissions']) {
      await b.report(r, from: today.subtract(const Duration(days: 30)), to: today);
    }
    await b.auditLogs();
    await b.settlements();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('5. kasir: diskon manual, voucher salah ditolak, refund sebagian, kas & piutang', () async {
    final b = owner.billing;
    final target = (await owner.api.patients(query: _phone.substring(_phone.length - 4))).items.first;
    final svc = (await owner.api.services(owner.branchId)).first;
    final me = (await owner.api.therapists(owner.branchId)).where((t) => t.id == terapis.user.id).single;
    final s = await owner.api.createSession(
      patientId: target.id, serviceId: svc.id, branchId: owner.branchId, therapistId: me.id, walkIn: true);
    final sender = ApiOutboxSender(terapis.client);
    OutboxItem item(String kind, Map<String, dynamic> p) => OutboxItem(
      id: newId(), kind: kind, entityId: s.id, payload: p, baseVersion: 0,
      createdAt: DateTime.now(), nextAttemptAt: DateTime.now());
    expect(await sender.send(item(OutboxKinds.sessionStatus, {'status': 'running'})), isNot(isA<SendError>()));
    final area = ((await terapis.client.get('/v1/body-areas', (d) => d)) as List).first as Map;
    final rec = SessionRecord(
      id: newId(), sessionId: s.id, patientId: target.id, therapistId: me.id, complaint: 'E2E kasir',
      treatedAreas: ['${area['code']}:both'], painBefore: 5, painAfter: 2, treatments: const ['Adjustment'],
      updatedAt: DateTime.now());
    expect(await sender.send(item(OutboxKinds.sessionRecordUpsert, rec.toJson())), isNot(isA<SendError>()));
    expect(await sender.send(item(OutboxKinds.sessionStatus, {'status': 'done'})), isNot(isA<SendError>()));

    var inv = (await b.invoiceForSession(s.id))!;
    // invoice_detail_page.dart: voucher tidak dikenal → 422/409, bukan crash.
    await expectLater(b.updateInvoice(inv.id, {'voucher_code': 'TIDAKADA999'}), throwsA(isA<AppError>()));
    // Diskon manual kecil dengan alasan.
    inv = await b.updateInvoice(inv.id, {'manual_discount': {'type': 'amount', 'value': 1000, 'reason': 'E2E'}});
    expect(inv.manualDiscount, anyOf(1000, 0)); // 0 bila di atas batas → menunggu owner
    if (inv.status == 'draft') inv = await b.issue(inv.id);
    if (inv.manualDiscountStatus == 'pending_approval') {
      final ap = (await b.approvals('manual_discount')).firstWhere((a) => a.subjectId == inv.id);
      await b.decide(ap.id, approve: true);
      inv = await b.invoice(inv.id);
    }
    final paid = await b.pay(inv.id, {'method': 'cash', 'amount': inv.balance, 'cash_received': inv.balance + 5000});
    expect(paid.invoice.status, 'paid');
    expect(paid.payment.changeGiven, 5000);

    // refund_page.dart: refund sebagian tunai.
    final rf = await b.refund(inv.id, {'kind': 'partial', 'amount': 1000, 'reason_code': 'keluhan', 'note': 'E2E', 'method': 'cash'});
    expect(rf.amount, 1000);
    if (rf.status == 'pending_approval') {
      final ap = (await b.approvals('refund')).firstWhere((a) => a.subjectId == rf.id);
      await b.decide(ap.id, approve: true);
    }

    // Layar kas & piutang terbaca.
    await b.closingPreview();
    await b.receivables();
    await b.transfersToVerify();
    await b.handovers(status: 'handed_over');
    await terapis.billing.myCash();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  test('6. terapis kirim program latihan → pasien centang; alamat & preferensi pasien', () async {
    final target = (await owner.api.patients(query: _phone.substring(_phone.length - 4))).items.first;
    final area = ((await owner.client.get('/v1/body-areas', (d) => d)) as List).first as Map;
    final ex = await owner.billing.saveExercise(null, {
      'name': 'E2E program ${DateTime.now().millisecondsSinceEpoch}', 'level': 'easy',
      'body_area_codes': [area['code']], 'steps': ['Tarik napas'], 'default_sets': 2, 'default_reps': 8,
    });
    final now = DateTime.now();
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    // program_latihan_page.dart
    final prog = await terapis.billing.sendProgram(target.id, {
      'starts_on': day(now), 'ends_on': day(now.add(const Duration(days: 13))), 'note': 'E2E',
      'items': [{'exercise_id': ex.id, 'sets': 2, 'reps': 8, 'duration_sec': null, 'per_day': 1}],
    });
    expect(prog.items, hasLength(1));

    // latihan_page.dart (pasien)
    final mine = (await pasien.programs()).where((p) => p.id == prog.id).single;
    await pasien.logExercise(mine.items.first.id, done: true);
    final after = (await pasien.programs()).where((p) => p.id == prog.id).single;
    expect(after.items.first.doneToday, isTrue);

    // alamat_page.dart
    final addr = await pasien.saveAddress(null, {
      'label': 'E2E', 'address': 'Jl. Uji No. 1, Malang', 'landmark': null, 'lat': -7.9666, 'lng': 112.6326, 'is_default': false,
    });
    expect((await pasien.addresses()).map((a) => a.id), contains(addr.id));
    await pasien.deleteAddress(addr.id);

    // notifikasi_page.dart: preferensi bolak-balik
    final c = await pasien.consent();
    await pasien.saveConsent(reminders: c.reminders, promo: !c.promo, policyVersion: 'app');
    await pasien.saveConsent(reminders: c.reminders, promo: c.promo, policyVersion: 'app');
    await pasien.points();
    await pasien.notifications();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
