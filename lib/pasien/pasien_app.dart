import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/shell/role_shell.dart';
import '../theme/app_theme.dart';
import '../ui/ui.dart';
import 'beranda/beranda_page.dart';
import 'booking/bayar_page.dart';
import 'booking/booking_page.dart';
import 'booking/jadwal_saya_page.dart';
import 'booking/ubah_jadwal_page.dart';
import 'latihan/detail_latihan_page.dart';
import 'latihan/latihan_page.dart';
import 'masuk/hubungkan_page.dart';
import 'masuk/onboarding_page.dart';
import 'masuk/otp_page.dart';
import 'masuk/persetujuan_page.dart';
import 'pasien_routes.dart';
import 'pasien_session.dart';
import 'profil/alamat_page.dart';
import 'profil/beli_paket_page.dart';
import 'profil/hapus_akun_page.dart';
import 'profil/notifikasi_page.dart';
import 'profil/paket_page.dart';
import 'profil/poin_page.dart';
import 'profil/profil_page.dart';
import 'profil/riwayat_sesi_page.dart';
import 'profil/struk_page.dart';

final pasienNavigatorKey = GlobalKey<NavigatorState>();
final pasienMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Ke mana pengguna diarahkan menurut tahap masuk (§5.13).
String? pasienRedirect(PasienPhase phase, String location) {
  final entry = switch (phase) {
    PasienPhase.onboarding => PRoutes.onboarding,
    PasienPhase.otp => PRoutes.masuk,
    PasienPhase.link => PRoutes.hubungkan,
    PasienPhase.consent => PRoutes.persetujuan,
    PasienPhase.ready => null,
  };
  if (entry != null) return location == entry ? null : entry;
  return PRoutes.isEntry(location) || location == '/' ? PRoutes.beranda : null;
}

GoRoute _push(String path, Widget Function(GoRouterState s) build) => GoRoute(
  path: path,
  parentNavigatorKey: pasienNavigatorKey,
  builder: (_, s) => build(s),
);

StatefulShellBranch _tab(String path, Widget page) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      pageBuilder: (_, _) => NoTransitionPage(child: page),
    ),
  ],
);

final pasienRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(pasienSessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: pasienNavigatorKey,
    initialLocation: PRoutes.onboarding,
    refreshListenable: refresh,
    redirect: (_, state) => pasienRedirect(
      ref.read(pasienSessionProvider).phase,
      state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: PRoutes.onboarding,
        pageBuilder: (_, s) => olFadePage(s, const OnboardingPage()),
      ),
      GoRoute(
        path: PRoutes.masuk,
        pageBuilder: (_, s) => olFadePage(s, const OtpPage()),
      ),
      GoRoute(
        path: PRoutes.hubungkan,
        pageBuilder: (_, s) => olFadePage(s, const HubungkanPage()),
      ),
      GoRoute(
        path: PRoutes.persetujuan,
        pageBuilder: (_, s) => olFadePage(s, const PersetujuanPage()),
      ),
      StatefulShellRoute(
        navigatorContainerBuilder: (_, shell, children) => FadeThroughBranches(
          currentIndex: shell.currentIndex,
          children: children,
        ),
        pageBuilder: (_, s, shell) => olFadePage(
          s,
          OlTabShell(
            shell: shell,
            tabs: const [
              TabSpec('Beranda', OlIcons.home),
              TabSpec('Latihan', OlIcons.exercise),
              TabSpec('Booking', OlIcons.calendar),
              TabSpec('Profil', OlIcons.user),
            ],
          ),
        ),
        branches: [
          _tab(PRoutes.beranda, const BerandaPage()),
          _tab(PRoutes.latihan, const LatihanPage()),
          _tab(PRoutes.booking, const BookingPage()),
          _tab(PRoutes.profil, const ProfilPage()),
        ],
      ),
      _push(
        '/latihan/:id',
        (s) => DetailLatihanPage(id: s.pathParameters['id']!),
      ),
      _push(PRoutes.bayar, (_) => const BayarPage()),
      _push(PRoutes.jadwal, (_) => const JadwalSayaPage()),
      _push(PRoutes.ubahJadwal, (_) => const UbahJadwalPage()),
      _push(PRoutes.riwayat, (_) => const RiwayatSesiPage()),
      _push(PRoutes.paket, (_) => const PaketPage()),
      _push(PRoutes.beliPaket, (_) => const BeliPaketPage()),
      _push(PRoutes.struk, (_) => const StrukPasienPage()),
      _push(PRoutes.poin, (_) => const PoinPasienPage()),
      _push(PRoutes.notifikasi, (_) => const NotifikasiPasienPage()),
      _push(PRoutes.alamat, (_) => const AlamatPage()),
      _push(PRoutes.hapusAkun, (_) => const HapusAkunPage()),
      _push(PRoutes.kebijakan, (_) => const PersetujuanPage(review: true)),
    ],
  );
});

/// Aplikasi pasien One Lotus (Fase 3) — memakai tema & komponen yang sama
/// dengan aplikasi staf; copy memakai "Anda" (§11).
class PasienApp extends ConsumerStatefulWidget {
  const PasienApp({super.key});

  @override
  ConsumerState<PasienApp> createState() => _PasienAppState();
}

class _PasienAppState extends ConsumerState<PasienApp> {
  final _feedback = AppFeedback(
    messengerKey: pasienMessengerKey,
    navigatorKey: pasienNavigatorKey,
  );

  @override
  Widget build(BuildContext context) => FeedbackScope(
    feedback: _feedback,
    child: MaterialApp.router(
      title: 'One Lotus',
      debugShowCheckedModeBanner: false,
      theme: buildOlTheme(),
      locale: const Locale('id'),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scaffoldMessengerKey: pasienMessengerKey,
      routerConfig: ref.watch(pasienRouterProvider),
    ),
  );
}
