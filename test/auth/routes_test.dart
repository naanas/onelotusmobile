import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/auth/mock_auth_repository.dart';
import 'package:onelotus_staff/data/models/staff_user.dart';
import 'package:onelotus_staff/router/routes.dart';

const _user = StaffUser(
  id: 'x',
  username: 'x',
  name: 'X',
  roles: [Role.terapis],
  branches: [MockBranches.pusat],
);

AuthState ready(Role role) => AuthState(
  phase: AuthPhase.ready,
  user: _user,
  token: 't',
  activeRole: role,
  activeBranch: MockBranches.pusat,
);

void main() {
  test('belum login hanya boleh di login & lupa password', () {
    const s = AuthState(phase: AuthPhase.signedOut);
    expect(authRedirect(s, Routes.terapisJadwal), Routes.login);
    expect(authRedirect(s, Routes.login), isNull);
    expect(authRedirect(s, Routes.forgotPassword), isNull);
    expect(authRedirect(s, Routes.splash), Routes.login);
  });

  test('fase setup & kunci memaksa layar masing-masing', () {
    expect(
      authRedirect(const AuthState(phase: AuthPhase.booting), Routes.login),
      Routes.splash,
    );
    expect(
      authRedirect(
        const AuthState(phase: AuthPhase.firstLogin),
        Routes.kasirAntrian,
      ),
      Routes.firstLogin,
    );
    expect(
      authRedirect(const AuthState(phase: AuthPhase.chooseContext), '/'),
      Routes.chooseContext,
    );
    expect(
      authRedirect(
        const AuthState(phase: AuthPhase.locked),
        Routes.ownerLaporan,
      ),
      Routes.lock,
    );
    expect(
      authRedirect(
        const AuthState(phase: AuthPhase.sessionExpired),
        Routes.login,
      ),
      Routes.sessionExpired,
    );
  });

  test('siap: halaman auth → beranda peran', () {
    expect(
      authRedirect(ready(Role.terapis), Routes.login),
      Routes.terapisJadwal,
    );
    expect(authRedirect(ready(Role.kasir), Routes.lock), Routes.kasirAntrian);
    expect(
      authRedirect(ready(Role.owner), Routes.splash),
      Routes.ownerRingkasan,
    );
  });

  test('§7: path peran lain dialihkan ke beranda peran aktif', () {
    expect(
      authRedirect(ready(Role.terapis), Routes.ownerLaporan),
      Routes.terapisJadwal,
    );
    expect(
      authRedirect(ready(Role.terapis), Routes.kasirKasir),
      Routes.terapisJadwal,
    );
    expect(
      authRedirect(ready(Role.kasir), Routes.terapisPilihPasien),
      Routes.kasirAntrian,
    );
    expect(authRedirect(ready(Role.terapis), Routes.terapisRiwayat), isNull);
    expect(authRedirect(ready(Role.owner), Routes.chooseContext), isNull);
  });
}
