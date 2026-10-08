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
import '../features/umum/change_password_page.dart';
import '../features/umum/help_page.dart';
import '../features/umum/maintenance_page.dart';
import '../features/umum/notification_settings_page.dart';
import '../features/umum/notifications_page.dart';
import '../features/umum/search_page.dart';
import '../features/umum/sync_status_page.dart';
import '../features/umum/update_page.dart';
import '../features/kasir/antrian_page.dart';
import '../features/kasir/bayar_page.dart';
import '../features/kasir/booking_page.dart';
import '../features/kasir/buat_jadwal_page.dart';
import '../features/kasir/detail_pasien_kasir_page.dart';
import '../features/kasir/intake_page.dart';
import '../features/kasir/pasien_form_page.dart';
import '../features/kasir/pasien_page.dart';
import '../features/kasir/pindah_massal_page.dart';
import '../features/kasir/tagihan_page.dart';
import '../features/shell/placeholder_tab_page.dart';
import '../features/shell/role_shell.dart';
import '../features/terapis/akun/kas_dibawa_page.dart';
import '../features/terapis/rekam/rekam_sesi_page.dart';
import '../features/terapis/akun/komisi_page.dart';
import '../features/terapis/home_visit/home_visit_page.dart';
import '../features/terapis/home_visit/tagih_page.dart';
import '../features/terapis/jadwal/ajukan_cuti_page.dart';
import '../features/terapis/jadwal/pilih_pasien_page.dart';
import '../features/terapis/pasien/program_latihan_page.dart';
import '../features/terapis/jadwal/jadwal_minggu_page.dart';
import '../features/terapis/pasien/detail_pasien_page.dart';
import '../features/terapis/pasien/pasien_saya_page.dart';
import '../features/terapis/riwayat/detail_sesi_page.dart';
import '../features/terapis/riwayat/riwayat_page.dart';
import '../features/terapis/jadwal/jadwal_controller.dart';
import '../features/terapis/jadwal/jadwal_page.dart';
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
            fab: FabSpec(
              'Rekam sesi atau pilih pasien',
              Routes.terapisPilihPasien,
              // §3: ada sesi berjalan → langsung ke rekam sesi; bila tidak → pilih pasien.
              resolve: (ref) {
                final running = ref.read(runningSessionProvider);
                return running == null
                    ? Routes.terapisPilihPasien
                    : Routes.terapisRekam(running.id);
              },
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
          _branch(Routes.terapisJadwal, const JadwalPage()),
          _branch(Routes.terapisPasien, const PasienSayaPage()),
          _branch(Routes.terapisRiwayat, const RiwayatPage()),
          _branch(Routes.terapisAkun, const AkunPage()),
        ],
      ),
      GoRoute(
        path: Routes.terapisPilihPasien,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PilihPasienPage(),
      ),
      GoRoute(
        path: '/terapis/jadwal-minggu',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const JadwalMingguPage(),
      ),
      GoRoute(
        path: Routes.terapisAjukanCuti,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const AjukanCutiPage(),
      ),
      GoRoute(
        path: '/terapis/pasien/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => DetailPasienPage(patientId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/terapis/sesi/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => DetailSesiPage(sessionId: s.pathParameters['id']!),
      ),

      GoRoute(
        path: '/terapis/home-visit/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => HomeVisitPage(sessionId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/terapis/home-visit/:id/tagih',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const TagihPage(),
      ),
      GoRoute(
        path: '/terapis/pasien/:id/latihan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) =>
            ProgramLatihanPage(patientId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.terapisKas,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const KasDibawaPage(),
      ),
      GoRoute(
        path: Routes.terapisKomisi,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const KomisiPage(),
      ),

      GoRoute(
        path: '/terapis/rekam/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => RekamSesiPage(sessionId: s.pathParameters['id']!),
      ),

      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(
        path: Routes.search,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SearchPage(),
      ),
      GoRoute(
        path: Routes.syncStatus,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SyncStatusPage(),
      ),
      GoRoute(
        path: Routes.changePassword,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: Routes.notificationSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: Routes.help,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const HelpPage(),
      ),
      GoRoute(
        path: Routes.update,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const UpdatePage(),
      ),
      GoRoute(
        path: Routes.maintenance,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const MaintenancePage(),
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
          _branch(Routes.kasirAntrian, const AntrianPage()),
          _branch(Routes.kasirPasien, const KasirPasienPage()),
          _branch(Routes.kasirKasir, const TagihanPage()),
          _branch(Routes.kasirAkun, const AkunPage()),
        ],
      ),
      GoRoute(
        path: Routes.kasirIntake,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const IntakePage(),
      ),
      GoRoute(
        path: Routes.kasirPasienForm,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PasienFormPage(),
      ),
      GoRoute(
        path: Routes.kasirBuatJadwal,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const BuatJadwalPage(),
      ),
      GoRoute(
        path: Routes.kasirBooking,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const BookingPage(),
      ),
      GoRoute(
        path: Routes.kasirPindahMassal,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PindahMassalPage(),
      ),
      GoRoute(
        path: Routes.kasirBayar,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const BayarPage(),
      ),
      GoRoute(
        path: '/kasir/pasien/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) =>
            DetailPasienKasirPage(patientId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.kasirStruk,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PlaceholderScreen(
          title: 'Konfirmasi & struk',
          screenId: 'KS-11',
          stage: 'slicing berikutnya',
        ),
      ),
      GoRoute(
        path: Routes.kasirJualPaket,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PlaceholderScreen(
          title: 'Jual paket',
          screenId: 'KS-12',
          stage: 'slicing berikutnya',
        ),
      ),
      GoRoute(
        path: Routes.kasirRiwayat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PlaceholderScreen(
          title: 'Riwayat transaksi',
          screenId: 'KS-13',
          stage: 'slicing berikutnya',
        ),
      ),
      GoRoute(
        path: Routes.kasirRefund,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PlaceholderScreen(
          title: 'Refund / batal',
          screenId: 'KS-14',
          stage: 'slicing berikutnya',
        ),
      ),
      GoRoute(
        path: Routes.kasirVerifikasiTransfer,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PlaceholderScreen(
          title: 'Verifikasi transfer',
          screenId: 'KS-15',
          stage: 'slicing berikutnya',
        ),
      ),
      GoRoute(
        path: Routes.kasirTerimaKas,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PlaceholderScreen(
          title: 'Terima kas terapis',
          screenId: 'KS-16',
          stage: 'slicing berikutnya',
        ),
      ),
      GoRoute(
        path: Routes.kasirTutupKas,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PlaceholderScreen(
          title: 'Tutup kas harian',
          screenId: 'KS-17',
          stage: 'slicing berikutnya',
        ),
      ),
      GoRoute(
        path: Routes.kasirPiutang,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PlaceholderScreen(
          title: 'Piutang',
          screenId: 'KS-18',
          stage: 'slicing berikutnya',
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
