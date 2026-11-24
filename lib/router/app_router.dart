import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth/auth_controller.dart';
import '../pasien/pasien_router.dart';
import '../pasien/pasien_session.dart';
import '../features/auth/choose_context_page.dart';
import '../features/auth/first_login_page.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/auth/lock_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/session_expired_page.dart';
import '../features/auth/splash_page.dart';
import '../features/klinik/export_page.dart';
import '../features/klinik/formulir_page.dart';
import '../features/klinik/klinik_models.dart';
import '../features/klinik/lainnya_page.dart';
import '../features/klinik/notifikasi.dart';
import '../features/klinik/pasien_detail_page.dart';
import '../features/klinik/pasien_form_page.dart';
import '../features/klinik/pasien_list_page.dart';
import '../features/klinik/pemeriksaan_form_page.dart';
import '../features/klinik/rekap_page.dart';
import '../features/klinik/user_page.dart';
import '../features/shell/role_shell.dart';
import '../features/umum/change_password_page.dart';
import '../features/umum/help_page.dart';
import '../features/umum/maintenance_page.dart';
import '../features/umum/update_page.dart';
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

GoRoute _root(String path, Widget Function(GoRouterState s) build) => GoRoute(
  path: path,
  parentNavigatorKey: rootNavigatorKey,
  builder: (_, s) => build(s),
);

final routerProvider = Provider<GoRouter>((ref) {
  // Router dibuat sekali; perubahan status login memicu redirect lewat refreshListenable.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (prev, next) {
    // Staf yang baru logout langsung ke layar masuk, tanpa perkenalan pasien.
    final wasIn =
        prev != null &&
        prev.phase != AuthPhase.booting &&
        prev.phase != AuthPhase.signedOut;
    if (wasIn &&
        next.phase == AuthPhase.signedOut &&
        ref.read(pasienSessionProvider).phase == PasienPhase.onboarding) {
      ref.read(pasienSessionProvider.notifier).finishOnboarding();
    }
    refresh.value++;
  });
  ref.listen(pasienSessionProvider, (_, _) => refresh.value++);
  ref.listen(appStatusProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      ref.read(authProvider),
      ref.read(pasienSessionProvider),
      state.matchedLocation,
      ref.read(appStatusProvider),
    ),
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

      // ── Staf (admin & terapis): Data Pasien · Rekap · + · Formulir · Lainnya ──
      StatefulShellRoute(
        navigatorContainerBuilder: _fadeThrough,
        pageBuilder: (context, state, shell) => olFadePage(
          state,
          RoleShell(
            shell: shell,
            fab: const FabSpec('Tambah pasien', Routes.klinikTambahPasien),
            tabs: const [
              TabSpec('Data Pasien', OlIcons.users),
              TabSpec('Rekap', OlIcons.chart),
              TabSpec('Formulir', OlIcons.receipt),
              TabSpec('Lainnya', OlIcons.grid),
            ],
          ),
        ),
        branches: [
          _branch(Routes.klinikPasien, const PasienListPage()),
          _branch(Routes.klinikRekap, const RekapPage()),
          _branch(Routes.klinikFormulir, const FormulirPage()),
          _branch(Routes.klinikLainnya, const LainnyaPage()),
        ],
      ),
      _root(Routes.klinikTambahPasien, (_) => const PasienFormPage()),
      _root('/klinik/edit-pasien/:id', (s) => PasienFormPage(editId: s.pathParameters['id'])),
      _root(
        '/klinik/detail-pasien/:id',
        (s) => PasienDetailPage(id: s.pathParameters['id']!, initial: s.extra is Pasien ? s.extra as Pasien : null),
      ),
      _root(
        '/klinik/detail-pasien/:id/tambah-pemeriksaan',
        (s) => PemeriksaanFormPage(
          pasienId: s.pathParameters['id'],
          prefill: s.extra is PemeriksaanDraft ? s.extra as PemeriksaanDraft : null,
          lanjutDetail: s.uri.queryParameters['lanjut'] == 'detail',
        ),
      ),
      _root(
        '/klinik/edit-pemeriksaan/:id',
        (s) => PemeriksaanFormPage(
          pemeriksaanId: int.tryParse(s.pathParameters['id']!) ?? 0,
          editing: s.extra is Pemeriksaan ? s.extra as Pemeriksaan : null,
        ),
      ),
      _root(
        '/klinik/formulir/:id',
        (s) => FormulirDetailPage(
          id: s.pathParameters['id']!,
          initial: s.extra is Formulir ? s.extra as Formulir : null,
        ),
      ),
      _root(Routes.klinikExport, (_) => const ExportPage()),
      _root(Routes.klinikUser, (_) => const UserPage()),
      _root(Routes.klinikNotifikasi, (_) => const StaffNotifikasiPage()),
      _root(Routes.changePassword, (_) => const ChangePasswordPage()),
      _root(Routes.help, (_) => const HelpPage()),
      _root(Routes.update, (_) => const UpdatePage()),
      _root(Routes.maintenance, (_) => const MaintenancePage()),

      // ── Pasien: Beranda · Latihan · Booking · Profil (satu aplikasi) ──
      ...pasienRoutes(rootNavigatorKey),
    ],
  );
});
