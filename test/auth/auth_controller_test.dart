import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/auth/session_store.dart';
import 'package:onelotus_staff/data/models/staff_user.dart';

import 'fakes.dart';

void main() {
  late AuthHarness h;
  late ProviderContainer c;
  AuthController auth() => c.read(authProvider.notifier);
  AuthState state() => c.read(authProvider);

  setUp(() {
    h = AuthHarness();
    c = h.container();
  });
  tearDown(() => c.dispose());

  Future<void> loginAndSetup(String user, String pw) async {
    expect(await auth().login(user, pw), isA<LoginOk>());
    expect(state().phase, AuthPhase.firstLogin);
    await auth().setPin('123456');
    await auth().completeFirstLogin();
  }

  test(
    'kasir 1 peran: login → atur PIN → langsung siap, tanpa UM-08',
    () async {
      await auth().bootstrap();
      expect(state().phase, AuthPhase.signedOut);
      expect(await auth().login('sinta.kasir', 'kasir123'), isA<LoginOk>());
      expect(state().phase, AuthPhase.firstLogin);
      expect(state().firstLoginStartStep, 2);
      await auth().setPin('123456');
      await auth().completeFirstLogin();
      expect(state().phase, AuthPhase.ready);
      expect(state().activeRole, Role.kasir);
    },
  );

  test('akun >1 peran/cabang diarahkan ke UM-08', () async {
    await loginAndSetup('dimas.terapis', 'terapis123');
    expect(state().phase, AuthPhase.chooseContext);
    await auth().chooseContext(Role.kasir, state().user!.branches.last);
    expect(state().phase, AuthPhase.ready);
    expect(state().activeRole, Role.kasir);
    expect(state().activeBranch!.id, 'batu');
  });

  test(
    'password sementara: mulai dari langkah 1, password baru harus beda',
    () async {
      expect(await auth().login('baru.terapis', 'sementara1'), isA<LoginOk>());
      expect(state().firstLoginStartStep, 1);
      expect(auth().validateNewPassword('pendek'), isNotNull);
      expect(
        auth().validateNewPassword('sementara1'),
        'Harus berbeda dari password sementara.',
      );
      expect(auth().validateNewPassword('BaruSekali9'), isNull);
      await auth().changeTemporaryPassword('BaruSekali9');
      expect(state().user!.mustChangePassword, isFalse);

      // Password lama tidak berlaku lagi.
      await auth().logout();
      expect(
        await auth().login('baru.terapis', 'sementara1'),
        isA<LoginInvalid>(),
      );
      expect(await auth().login('baru.terapis', 'BaruSekali9'), isA<LoginOk>());
    },
  );

  test('gagal 5× → terkunci 5 menit, lalu bisa lagi', () async {
    for (var i = 1; i <= 4; i++) {
      final r = await auth().login('sinta.kasir', 'salah');
      expect((r as LoginInvalid).remainingAttempts, 5 - i);
    }
    expect(await auth().login('sinta.kasir', 'salah'), isA<LoginLocked>());
    // Password benar pun ditolak selama terkunci.
    expect(await auth().login('sinta.kasir', 'kasir123'), isA<LoginLocked>());
    h.clock.advance(const Duration(minutes: 4, seconds: 59));
    expect(await auth().loginLockedUntil(), isNotNull);
    h.clock.advance(const Duration(seconds: 2));
    expect(await auth().loginLockedUntil(), isNull);
    expect(await auth().login('sinta.kasir', 'kasir123'), isA<LoginOk>());
  });

  test('akun nonaktif', () async {
    expect(await auth().login('lama.kasir', 'kasir123'), isA<LoginDisabled>());
  });

  test(
    'buka ulang dengan token & PIN → UM-07; salah 5× → logout paksa & PIN dihapus',
    () async {
      await loginAndSetup('sinta.kasir', 'kasir123');
      final c2 = ProviderContainer(overrides: h.overrides);
      addTearDown(c2.dispose);
      final a2 = c2.read(authProvider.notifier);
      await a2.bootstrap();
      expect(c2.read(authProvider).phase, AuthPhase.locked);

      expect(await a2.unlockWithPin('000000'), isA<PinWrong>());
      expect(await a2.remainingPinAttempts(), 4);
      for (var i = 0; i < 3; i++) {
        await a2.unlockWithPin('000000');
      }
      expect(await a2.unlockWithPin('000000'), isA<PinForcedLogout>());
      expect(c2.read(authProvider).phase, AuthPhase.signedOut);
      expect(h.store.data[SessionKeys.pinHash('u2')], isNull);
      expect(h.store.data[SessionKeys.token], isNull);
    },
  );

  test('PIN benar membuka kunci & mereset hitungan salah', () async {
    await loginAndSetup('sinta.kasir', 'kasir123');
    auth().onBackground();
    h.clock.advance(const Duration(minutes: 5));
    await auth().onForeground();
    expect(state().phase, AuthPhase.locked);
    await auth().unlockWithPin('111111');
    expect(await auth().unlockWithPin('123456'), isA<PinOk>());
    expect(state().phase, AuthPhase.ready);
    expect(await auth().remainingPinAttempts(), 5);
  });

  test('kembali < 5 menit tidak mengunci', () async {
    await loginAndSetup('sinta.kasir', 'kasir123');
    auth().onBackground();
    h.clock.advance(const Duration(minutes: 4, seconds: 59));
    await auth().onForeground();
    expect(state().phase, AuthPhase.ready);
  });

  test(
    'biometrik: aktif setelah verifikasi, dipakai untuk membuka kunci',
    () async {
      expect(await auth().login('sinta.kasir', 'kasir123'), isA<LoginOk>());
      await auth().setPin('123456');
      expect(await auth().enableBiometric(), isTrue);
      await auth().completeFirstLogin();
      auth().onBackground();
      h.clock.advance(const Duration(minutes: 10));
      await auth().onForeground();
      expect(await auth().unlockWithBiometric(), isTrue);
      expect(state().phase, AuthPhase.ready);
    },
  );

  test('"Ingat perangkat ini" mati → token tidak disimpan', () async {
    expect(
      await auth().login('sinta.kasir', 'kasir123', remember: false),
      isA<LoginOk>(),
    );
    expect(h.store.data[SessionKeys.token], isNull);
    final c2 = ProviderContainer(overrides: h.overrides);
    addTearDown(c2.dispose);
    await c2.read(authProvider.notifier).bootstrap();
    expect(c2.read(authProvider).phase, AuthPhase.signedOut);
  });

  test('Lupa PIN → login ulang lalu atur PIN baru (mulai langkah 2)', () async {
    await loginAndSetup('sinta.kasir', 'kasir123');
    await auth().forgotPin();
    expect(state().phase, AuthPhase.signedOut);
    expect(await auth().login('sinta.kasir', 'kasir123'), isA<LoginOk>());
    expect(state().phase, AuthPhase.firstLogin);
    expect(state().firstLoginStartStep, 2);
  });

  test('auth_expired → layar sesi berakhir → login', () async {
    await loginAndSetup('sinta.kasir', 'kasir123');
    await auth().expireSession();
    expect(state().phase, AuthPhase.sessionExpired);
    auth().acknowledgeSessionExpired();
    expect(state().phase, AuthPhase.signedOut);
  });
}
