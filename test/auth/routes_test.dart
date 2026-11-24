import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import '../support/mock_auth_repository.dart';
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
    expect(authRedirect(s, Routes.klinikPasien), Routes.login);
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
      authRedirect(const AuthState(phase: AuthPhase.firstLogin), Routes.klinikRekap),
      Routes.firstLogin,
    );
    expect(
      authRedirect(const AuthState(phase: AuthPhase.chooseContext), '/'),
      Routes.chooseContext,
    );
    expect(
      authRedirect(const AuthState(phase: AuthPhase.locked), Routes.klinikFormulir),
      Routes.lock,
    );
    expect(
      authRedirect(const AuthState(phase: AuthPhase.sessionExpired), Routes.login),
      Routes.sessionExpired,
    );
  });

  test('siap: halaman auth → Data Pasien (admin & terapis)', () {
    expect(authRedirect(ready(Role.terapis), Routes.login), Routes.klinikPasien);
    expect(authRedirect(ready(Role.admin), Routes.splash), Routes.klinikPasien);
  });

  test('menu Laravel: User Management hanya admin', () {
    expect(authRedirect(ready(Role.admin), Routes.klinikUser), isNull);
    expect(authRedirect(ready(Role.terapis), Routes.klinikUser), Routes.klinikLainnya);
    for (final r in [Role.admin, Role.terapis]) {
      expect(authRedirect(ready(r), Routes.klinikRekap), isNull);
      expect(authRedirect(ready(r), Routes.klinikFormulir), isNull);
      expect(authRedirect(ready(r), Routes.klinikExport), isNull);
      expect(authRedirect(ready(r), Routes.klinikDetail('abc')), isNull);
    }
  });
}
