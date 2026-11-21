import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth.dart';
import '../data/models.dart';
import '../features/export_page.dart';
import '../features/formulir_page.dart';
import '../features/lainnya_page.dart';
import '../features/login_page.dart';
import '../features/pasien_detail_page.dart';
import '../features/pasien_form_page.dart';
import '../features/pasien_list_page.dart';
import '../features/pemeriksaan_form_page.dart';
import '../features/rekap_page.dart';
import '../features/shell.dart';
import '../features/splash_page.dart';
import '../features/user_page.dart';
import '../ui/ui.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Alamat layar. Menu mengikuti sidebar Laravel: Data Pasien, Rekap Data, Tambah Pasien, Formulir,
/// Export Excel, User Management (admin).
abstract final class Routes {
  static const splash = '/splash';
  static const masuk = '/masuk';
  static const pasien = '/pasien';
  static const rekap = '/rekap';
  static const formulir = '/formulir';
  static const lainnya = '/lainnya';
  static const tambahPasien = '/tambah-pasien';
  static const export = '/export';
  static const user = '/user';
  static String detail(int id) => '/detail-pasien/$id';
  static String editPasien(int id) => '/edit-pasien/$id';

  /// extra: [PerawatanDraft] isian awal (dari Formulir). [lanjutDetail] = setelah simpan buka detail pasien
  /// (alur Tambah Pasien / Formulir); tanpa itu kembali ke layar sebelumnya.
  static String tambahPemeriksaan(int pasienId, {bool lanjutDetail = false}) =>
      '/detail-pasien/$pasienId/tambah-pemeriksaan${lanjutDetail ? '?lanjut=detail' : ''}';

  /// extra: [Perawatan] yang diedit.
  static String editPemeriksaan(int id) => '/edit-pemeriksaan/$id';
}

/// Router: belum login → Masuk; sudah login → tab Data Pasien.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (!auth.ready) return loc == Routes.splash ? null : Routes.splash;
      if (!auth.loggedIn) return loc == Routes.masuk ? null : Routes.masuk;
      if (loc == Routes.masuk || loc == Routes.splash) return Routes.pasien;
      if (loc == Routes.user && !auth.isAdmin) return Routes.lainnya;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: Routes.masuk, builder: (_, _) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => OlTabShell(
          shell: shell,
          tabs: const [
            TabSpec('Data Pasien', OlIcons.users),
            TabSpec('Rekap', OlIcons.chart),
            TabSpec('Formulir', OlIcons.receipt),
            TabSpec('Lainnya', OlIcons.grid),
          ],
          fab: const FabSpec('Tambah pasien', Routes.tambahPasien),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.pasien,
                builder: (_, _) => const PasienListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.rekap, builder: (_, _) => const RekapPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.formulir,
                builder: (_, _) => const FormulirPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.lainnya,
                builder: (_, _) => const LainnyaPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.tambahPasien,
        builder: (_, _) => const PasienFormPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/detail-pasien/:id',
        builder: (_, s) =>
            PasienDetailPage(id: int.parse(s.pathParameters['id']!)),
        routes: [
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'tambah-pemeriksaan',
            builder: (_, s) => PemeriksaanFormPage(
              pasienId: int.parse(s.pathParameters['id']!),
              prefill: s.extra is PerawatanDraft
                  ? s.extra! as PerawatanDraft
                  : null,
              lanjutDetail: s.uri.queryParameters['lanjut'] == 'detail',
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/edit-pasien/:id',
        builder: (_, s) =>
            PasienFormPage(editId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/edit-pemeriksaan/:id',
        builder: (_, s) => PemeriksaanFormPage(
          perawatanId: int.parse(s.pathParameters['id']!),
          editing: s.extra is Perawatan ? s.extra! as Perawatan : null,
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.export,
        builder: (_, _) => const ExportPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.user,
        builder: (_, _) => const UserPage(),
      ),
    ],
  );
});
