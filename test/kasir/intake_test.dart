import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/data/api/api_error_mapper.dart';
import 'package:onelotus_staff/data/intake/intake_repository.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/features/kasir/pasien_form_page.dart';

import '../data/api_error_mapper_test.dart' show http;
import '../helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('detail intake dari JSON API', () {
    final d = IntakeDetail.fromJson({
      'id': 'a',
      'queue_label': 'A-07',
      'name': 'Sari Wulandari',
      'complaint': 'Nyeri pinggang',
      'body_complete': true,
      'attachment_count': 1,
      'status': 'new',
      'stale': false,
      'created_at': '2026-10-09T07:41:00Z',
      'branch_id': 'malang',
      'birth_date': '1994-02-14',
      'gender': 'P',
      'phone': '081277882104',
      'height_cm': 162,
      'weight_kg': 55,
      'cause': 'kerja',
      'injury_duration': 2,
      'injury_duration_unit': 'week',
      'attachments': [
        {'id': 'x1', 'content_type': 'image/jpeg', 'size_bytes': 1200},
      ],
    });
    expect(d.summary.queueLabel, 'A-07');
    expect(d.birthDate, DateTime(1994, 2, 14));
    expect(d.gender, Gender.female);
    expect(d.cause, IntakeCause.kerja);
    expect(d.durationLabel, '2 minggu');
    expect(d.attachments.single.id, 'x1');
  });

  test('409 duplicate_patient membawa kandidat', () {
    final e = mapDioError(
      http(409, {
        'code': 'duplicate_patient',
        'message': '…',
        'candidates': [
          {'id': '1', 'number': 412, 'name': 'Andi', 'match': 'phone'},
        ],
      }),
    );
    expect(e, isA<DuplicatePatientError>());
    expect((e as DuplicatePatientError).candidates.single['number'], 412);
  });

  test('mock: verifikasi menghapus kiriman dari daftar', () async {
    final repo = MockPatientIntakeRepository();
    final before = await repo.pending('b');
    expect(before.map((i) => i.name), contains('Rizky Hakim'));
    expect(before.firstWhere((i) => i.name == 'Rizky Hakim').stale, isTrue);
    final d = await repo.detail('i2');
    final p = await repo.process(
      'i2',
      PatientDraft(
        name: d.summary.name,
        birthDate: d.birthDate,
        gender: d.gender,
        phone: d.phone,
      ),
    );
    expect(p.number, greaterThan(0));
    expect((await repo.pending('b')).map((i) => i.id), isNot(contains('i2')));
  });

  testWidgets('KS-04 dari intake: terisi otomatis, pasien ganda → gabung', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final repo = MockPatientIntakeRepository();
    await t.pumpWidget(
      ProviderScope(
        overrides: [patientIntakeRepositoryProvider.overrideWithValue(repo)],
        child: TestApp(
          scroll: false,
          child: const PasienFormPage(intakeId: 'i1'),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();

    expect(find.text('Verifikasi pasien baru'), findsOneWidget);
    expect(find.text('Sari Wulandari'), findsOneWidget);
    expect(find.text('14 Feb 1994'), findsOneWidget);
    await t.scrollUntilVisible(
      find.textContaining('sudah menyetujui'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Penyebab: Kerja'), findsOneWidget);

    await t.tap(find.text('Simpan & buat nomor pasien'));
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    // Sheet ST-08 muncul dengan data lama #0291.
    expect(find.textContaining('#0291', findRichText: true), findsWidgets);
    expect(find.text('Pasien dengan nama & tanggal lahir ini sudah ada.'), findsOneWidget);
  });
}
