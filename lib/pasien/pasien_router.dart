import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/shell/role_shell.dart';
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

/// Layar masuk pasien sesuai tahapnya; null bila sudah siap.
String? pasienEntry(PasienPhase phase) => switch (phase) {
  PasienPhase.onboarding => PRoutes.onboarding,
  PasienPhase.otp => PRoutes.masuk,
  PasienPhase.link => PRoutes.hubungkan,
  PasienPhase.consent => PRoutes.persetujuan,
  PasienPhase.ready => null,
};

/// Redirect di dalam bagian pasien menurut tahap masuk (§5.13).
String? pasienRedirect(PasienPhase phase, String location) {
  final entry = pasienEntry(phase);
  if (entry != null) return location == entry ? null : entry;
  return PRoutes.isEntry(location) ? PRoutes.beranda : null;
}

GoRoute _push(
  GlobalKey<NavigatorState> root,
  String path,
  Widget Function(GoRouterState s) build,
) => GoRoute(path: path, parentNavigatorKey: root, builder: (_, s) => build(s));

StatefulShellBranch _tab(String path, Widget page) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      pageBuilder: (_, _) => NoTransitionPage(child: page),
    ),
  ],
);

/// Rute bagian pasien — dipasang di router aplikasi yang sama dengan staf.
List<RouteBase> pasienRoutes(GlobalKey<NavigatorState> root) => [
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
    root,
    '/pasien/latihan/:id',
    (s) => DetailLatihanPage(id: s.pathParameters['id']!),
  ),
  _push(root, PRoutes.bayar, (_) => const BayarPage()),
  _push(root, PRoutes.jadwal, (_) => const JadwalSayaPage()),
  _push(root, PRoutes.ubahJadwal, (_) => const UbahJadwalPage()),
  _push(root, PRoutes.riwayat, (_) => const RiwayatSesiPage()),
  _push(root, PRoutes.paket, (_) => const PaketPage()),
  _push(root, PRoutes.beliPaket, (_) => const BeliPaketPage()),
  _push(root, PRoutes.struk, (_) => const StrukPasienPage()),
  _push(root, PRoutes.poin, (_) => const PoinPasienPage()),
  _push(root, PRoutes.notifikasi, (_) => const NotifikasiPasienPage()),
  _push(root, PRoutes.alamat, (_) => const AlamatPage()),
  _push(root, PRoutes.hapusAkun, (_) => const HapusAkunPage()),
  _push(root, PRoutes.kebijakan, (_) => const PersetujuanPage(review: true)),
];
