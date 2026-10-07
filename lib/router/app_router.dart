import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth/auth_controller.dart';
import '../features/akun/akun_page.dart';
import '../features/auth/choose_context_page.dart';
import '../features/auth/first_login_page.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/auth/lock_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/session_expired_page.dart';
import '../features/auth/splash_page.dart';
import '../features/dev/component_gallery_page.dart';
import '../features/shell/placeholder_tab_page.dart';
import '../features/shell/role_shell.dart';
import '../ui/ui.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRoute _tab(String path, Widget page) => GoRoute(
  path: path,
  pageBuilder: (context, state) => NoTransitionPage(child: page),
);

Widget _fadeThrough(
  BuildContext context,
  StatefulNavigationShell shell,
  List<Widget> children,
) => FadeThroughBranches(currentIndex: shell.currentIndex, children: children);

StatefulShellBranch _branch(String path, Widget page) =>
    StatefulShellBranch(routes: [_tab(path, page)]);

final routerProvider = Provider<GoRouter>((ref) {
  // Router dibuat sekali; perubahan status login memicu redirect lewat refreshListenable.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authProvider), state.matchedLocation),
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (_, state) => olFadePage(state, const SplashPage()),
      ),
      GoRoute(
        path: Routes.login,
        pageBuilder: (_, state) => olFadePage(state, const LoginPage()),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.firstLogin,
        pageBuilder: (_, state) => olFadePage(state, const FirstLoginPage()),
      ),
      GoRoute(
        path: Routes.chooseContext,
        pageBuilder: (_, state) => olFadePage(state, const ChooseContextPage()),
      ),
      GoRoute(
        path: Routes.lock,
        pageBuilder: (_, state) => olFadePage(state, const LockPage()),
      ),
      GoRoute(
        path: Routes.sessionExpired,
        pageBuilder: (_, state) =>
            olFadePage(state, const SessionExpiredPage()),
      ),
      GoRoute(
        path: Routes.devComponents,
        builder: (_, _) => const ComponentGalleryPage(),
      ),

      // ── Terapis: Jadwal · Pasien · + · Riwayat · Akun ─────────────────────
      StatefulShellRoute(
        navigatorContainerBuilder: _fadeThrough,
        pageBuilder: (context, state, shell) => olFadePage(
          state,
          RoleShell(
            shell: shell,
            fab: const FabSpec(
              'Rekam sesi atau pilih pasien',
              Routes.terapisPilihPasien,
            ),
            tabs: const [
              TabSpec('Jadwal', OlIcons.calendar),
              TabSpec('Pasien', OlIcons.users),
              TabSpec('Riwayat', OlIcons.history),
              TabSpec('Akun', OlIcons.user),
            ],
          ),
        ),
        branches: [
          _branch(
            Routes.terapisJadwal,
            const PlaceholderTabPage(
              title: 'Jadwal hari ini',
              screenId: 'TR-01',
              stage: 'Tahap 5',
              hero: true,
            ),
          ),
          _branch(
            Routes.terapisPasien,
            const PlaceholderTabPage(
              title: 'Pasien saya',
              screenId: 'TR-06',
              stage: 'Tahap 5',
              illustration: OlIllustration.emptySearch,
            ),
          ),
          _branch(
            Routes.terapisRiwayat,
            const PlaceholderTabPage(
              title: 'Riwayat',
              screenId: 'TR-07',
              stage: 'Tahap 5',
              illustration: OlIllustration.emptyInbox,
            ),
          ),
          _branch(Routes.terapisAkun, const AkunPage()),
        ],
      ),
      GoRoute(
        path: Routes.terapisPilihPasien,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PlaceholderScreen(
          title: 'Pilih pasien',
          screenId: 'TR-14',
          stage: 'Tahap 5',
        ),
      ),

      // ── Kasir: Antrian · Pasien · + · Kasir · Akun ────────────────────────
      StatefulShellRoute(
        navigatorContainerBuilder: _fadeThrough,
        pageBuilder: (context, state, shell) => olFadePage(
          state,
          RoleShell(
            shell: shell,
            fab: const FabSpec(
              'Pasien baru atau tampilkan QR intake',
              Routes.kasirIntake,
            ),
            tabs: const [
              TabSpec('Antrian', OlIcons.queue),
              TabSpec('Pasien', OlIcons.users),
              TabSpec('Kasir', OlIcons.receipt),
              TabSpec('Akun', OlIcons.user),
            ],
          ),
        ),
        branches: [
          _branch(
            Routes.kasirAntrian,
            const PlaceholderTabPage(
              title: 'Antrian',
              screenId: 'KS-01',
              stage: 'Tahap 7',
              hero: true,
            ),
          ),
          _branch(
            Routes.kasirPasien,
            const PlaceholderTabPage(
              title: 'Pasien',
              screenId: 'KS-03',
              stage: 'Fase 1',
              illustration: OlIllustration.emptySearch,
            ),
          ),
          _branch(
            Routes.kasirKasir,
            const PlaceholderTabPage(
              title: 'Kasir',
              screenId: 'KS-09',
              stage: 'Fase 2',
              illustration: OlIllustration.emptyPayment,
            ),
          ),
          _branch(Routes.kasirAkun, const AkunPage()),
        ],
      ),
      GoRoute(
        path: Routes.kasirIntake,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PlaceholderScreen(
          title: 'Intake QR',
          screenId: 'KS-02',
          stage: 'Tahap 7',
        ),
      ),

      // ── Owner: Ringkasan · Jadwal · Pasien · Laporan · Akun (tanpa FAB) ──
      StatefulShellRoute(
        navigatorContainerBuilder: _fadeThrough,
        pageBuilder: (context, state, shell) => olFadePage(
          state,
          RoleShell(
            shell: shell,
            tabs: const [
              TabSpec('Ringkasan', OlIcons.chart),
              TabSpec('Jadwal', OlIcons.calendar),
              TabSpec('Pasien', OlIcons.users),
              TabSpec('Laporan', OlIcons.report),
              TabSpec('Akun', OlIcons.user),
            ],
          ),
        ),
        branches: [
          _branch(
            Routes.ownerRingkasan,
            const PlaceholderTabPage(
              title: 'Ringkasan bisnis',
              screenId: 'OW-01',
              stage: 'Fase 2',
              hero: true,
              illustration: OlIllustration.progress,
            ),
          ),
          _branch(
            Routes.ownerJadwal,
            const PlaceholderTabPage(
              title: 'Jadwal',
              screenId: 'OW-02',
              stage: 'Fase 2',
            ),
          ),
          _branch(
            Routes.ownerPasien,
            const PlaceholderTabPage(
              title: 'Pasien',
              screenId: 'OW-03',
              stage: 'Fase 2',
              illustration: OlIllustration.emptySearch,
            ),
          ),
          _branch(
            Routes.ownerLaporan,
            const PlaceholderTabPage(
              title: 'Laporan',
              screenId: 'OW-04',
              stage: 'Fase 2',
              illustration: OlIllustration.progress,
            ),
          ),
          _branch(Routes.ownerAkun, const AkunPage()),
        ],
      ),
    ],
  );
});
