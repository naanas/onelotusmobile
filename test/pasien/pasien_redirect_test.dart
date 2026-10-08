import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/pasien/pasien_app.dart';
import 'package:onelotus_staff/pasien/pasien_routes.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';

void main() {
  test('tahap masuk mengunci ke layar tahapnya', () {
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
  });

  test('siap: layar masuk diarahkan ke beranda, layar lain bebas', () {
    expect(pasienRedirect(PasienPhase.ready, PRoutes.masuk), PRoutes.beranda);
    expect(pasienRedirect(PasienPhase.ready, '/'), PRoutes.beranda);
    expect(pasienRedirect(PasienPhase.ready, PRoutes.poin), isNull);
    expect(pasienRedirect(PasienPhase.ready, PRoutes.kebijakan), isNull);
  });
}
