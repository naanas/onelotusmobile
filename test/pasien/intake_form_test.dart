import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/intake/intake_form_repository.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/pasien/intake/intake_form_page.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';
import 'package:onelotus_staff/router/routes.dart';

import '../helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('isi QR KS-02 → kode cabang', () {
    expect(
      intakeCodeFromQr('onelotus://app/intake/51d8d4e0f12892d5'),
      '51d8d4e0f12892d5',
    );
    expect(intakeCodeFromQr('  onelotus://app/intake/abc '), 'abc');
    expect(intakeCodeFromQr('https://onelotuspt.com/intake/abc'), isNull);
    expect(intakeCodeFromQr('onelotus://app/intake/'), isNull);
    expect(intakeCodeFromQr('teks biasa'), isNull);
  });

  test(
    'formulir intake terbuka tanpa login, juga saat aplikasi baru dibuka',
    () {
      const p = PasienSession();
      for (final phase in [
        AuthPhase.booting,
        AuthPhase.signedOut,
        AuthPhase.locked,
      ]) {
        final auth = AuthState(phase: phase);
        expect(appRedirect(auth, p, Routes.intakeScan), isNull);
        expect(appRedirect(auth, p, Routes.intakeForm('abc')), isNull);
      }
      // Rute lain tetap mengikuti alur masuk.
      expect(
        appRedirect(const AuthState(phase: AuthPhase.signedOut), p, '/intakex'),
        isNot(isNull),
      );
    },
  );

  test('isian dikirim dengan format API', () {
    final json = IntakeSubmission(
      clientId: 'c1',
      name: 'Sari Wulandari',
      birthDate: DateTime(1994, 2, 14),
      gender: Gender.female,
      phone: '0812 7788 2104',
      complaint: 'Nyeri pinggang',
      healthConsent: true,
      weightKg: 55,
      cause: IntakeCause.tidakTahu,
      injuryDuration: 2,
      injuryDurationUnit: 'week',
    ).toJson();
    expect(json['birth_date'], '1994-02-14');
    expect(json['gender'], 'P');
    expect(json['cause'], 'tidak_tahu');
    expect(json['injury_duration_unit'], 'week');
    expect(json.containsKey('height_cm'), isFalse);
    expect(json['photos'], isEmpty);
  });

  Future<void> pumpForm(WidgetTester t, String code) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          intakeFormRepositoryProvider.overrideWithValue(
            MockIntakeFormRepository(),
          ),
        ],
        child: TestApp(scroll: false, child: IntakeFormPage(code: code)),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
  }

  testWidgets('form kosong: kirim → isian wajib ditandai', (t) async {
    await pumpForm(t, 'abc');
    expect(find.text('Formulir pasien baru'), findsOneWidget);
    expect(find.textContaining('Klinik Pusat Malang'), findsOneWidget);

    await t.tap(find.text('Kirim formulir'));
    await t.pumpAndSettle();
    expect(find.text('Isi nama lengkap (2–100 huruf).'), findsOneWidget);
    expect(find.textContaining('isian yang ditandai merah'), findsWidgets);
  });

  testWidgets('QR tidak berlaku', (t) async {
    await pumpForm(t, 'invalid');
    expect(find.text('Kode QR sudah tidak berlaku'), findsOneWidget);
  });

  testWidgets('terima kasih + nomor antrian', (t) async {
    await t.pumpWidget(
      TestApp(
        scroll: false,
        child: const IntakeThanksView(
          receipt: IntakeReceipt(queueLabel: 'A-07', firstName: 'Sari'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Terima kasih, Sari'), findsOneWidget);
    expect(find.text('A-07'), findsOneWidget);
  });
}
