import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/pasien/pasien_router.dart';
import 'package:onelotus_staff/pasien/pasien_routes.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';
import 'package:onelotus_staff/router/routes.dart';

void main() {
  test('tahap masuk pasien mengunci ke layar tahapnya', () {
    expect(
      pasienRedirect(PasienPhase.onboarding, PRoutes.beranda),
      PRoutes.onboarding,
    );
    expect(pasienRedirect(PasienPhase.otp, PRoutes.onboarding), PRoutes.masuk);
    expect(pasienRedirect(PasienPhase.link, PRoutes.masuk), PRoutes.hubungkan);
    expect(
      pasienRedirect(PasienPhase.consent, PRoutes.profil),
      PRoutes.persetujuan,
    );
    expect(pasienRedirect(PasienPhase.otp, PRoutes.masuk), isNull);
    expect(pasienRedirect(PasienPhase.ready, PRoutes.masuk), PRoutes.beranda);
    expect(pasienRedirect(PasienPhase.ready, PRoutes.poin), isNull);
  });

  group('satu aplikasi staf & pasien', () {
    const out = AuthState(phase: AuthPhase.signedOut);

    test('belum login: perkenalan pasien, login staf tetap bisa dibuka', () {
      const p = PasienSession();
      expect(appRedirect(out, p, Routes.splash), PRoutes.onboarding);
      expect(appRedirect(out, p, Routes.login), isNull);
      expect(appRedirect(out, p, Routes.forgotPassword), isNull);
      expect(appRedirect(out, p, Routes.terapisJadwal), PRoutes.onboarding);
    });

    test('memilih staf (atau baru logout staf): ke login staf', () {
      const p = PasienSession(staffMode: true);
      expect(appRedirect(out, p, Routes.splash), Routes.login);
      expect(appRedirect(out, p, Routes.kasirAntrian), Routes.login);
    });

    test('pasien siap: layar staf diarahkan ke beranda pasien', () {
      const p = PasienSession(phase: PasienPhase.ready);
      expect(appRedirect(out, p, Routes.splash), PRoutes.beranda);
      expect(appRedirect(out, p, PRoutes.paket), isNull);
      expect(appRedirect(out, p, Routes.ownerRingkasan), PRoutes.beranda);
    });

    test('sesi staf didahulukan atas bagian pasien', () {
      const p = PasienSession(phase: PasienPhase.ready);
      const locked = AuthState(phase: AuthPhase.locked);
      expect(appRedirect(locked, p, PRoutes.beranda), Routes.lock);
      const booting = AuthState(phase: AuthPhase.booting);
      expect(appRedirect(booting, p, PRoutes.beranda), Routes.splash);
    });
  });
}
