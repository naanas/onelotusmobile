import '../core/format.dart';
import '../data/auth/auth_controller.dart';
import '../data/auth/auth_repository.dart';
import '../data/models/staff_user.dart';
import '../pasien/pasien_router.dart';
import '../pasien/pasien_routes.dart';
import '../pasien/pasien_session.dart';

const klinikUserPath = Routes.klinikUser;

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/lupa-password';
  static const firstLogin = '/login-pertama';
  static const chooseContext = '/pilih-peran';
  static const lock = '/kunci';
  static const sessionExpired = '/sesi-berakhir';
  static const devComponents = '/dev/komponen';

  // Umum
  static const changePassword = '/ubah-password';
  static const help = '/bantuan';
  static const update = '/perbarui';
  static const maintenance = '/pemeliharaan';

  // Staf (admin & terapis), mengikuti sidebar Laravel:
  // Data Pasien · Rekap · [+ Tambah Pasien] · Formulir · Lainnya (Export Excel, User Management).
  static const klinikPasien = '/klinik/pasien';
  static const klinikRekap = '/klinik/rekap';
  static const klinikFormulir = '/klinik/formulir';
  static const klinikLainnya = '/klinik/lainnya';
  static const klinikTambahPasien = '/klinik/tambah-pasien';
  static const klinikExport = '/klinik/export';
  static const klinikUser = '/klinik/user';
  static String klinikDetail(String id) => '/klinik/detail-pasien/$id';
  static String klinikEditPasien(String id) => '/klinik/edit-pasien/$id';

  /// extra: [Formulir] yang sudah dimuat (opsional).
  static String klinikFormulirDetail(String id) => '/klinik/formulir/$id';

  /// extra: [PemeriksaanDraft] isian awal (dari Formulir). [lanjutDetail] = setelah simpan buka detail pasien
  /// (alur Tambah Pasien / Formulir); tanpa itu kembali ke layar sebelumnya.
  static String klinikTambahPemeriksaan(String pasienId, {bool lanjutDetail = false}) =>
      '/klinik/detail-pasien/$pasienId/tambah-pemeriksaan${lanjutDetail ? '?lanjut=detail' : ''}';

  /// extra: [Pemeriksaan] yang diedit.
  static String klinikEditPemeriksaan(int id) => '/klinik/edit-pemeriksaan/$id';

  static String home(Role role) => klinikPasien;

  static const _authPages = {
    splash,
    login,
    forgotPassword,
    firstLogin,
    lock,
    sessionExpired,
  };
}

/// Redirect aplikasi (satu aplikasi untuk staf & pasien, satu layar masuk).
/// Sesi staf aktif (atau sedang dipulihkan/terkunci) selalu didahulukan.
/// Belum login: perkenalan pasien sekali, lalu layar masuk bersama yang
/// mengenali nomor HP (pasien) atau username (staf).
String? appRedirect(
  AuthState auth,
  PasienSession pasien,
  String location, [
  AppStatus? status,
]) {
  // UM-03 / UM-02 dari `/v1/app/status` (dibaca saat splash): pemeliharaan & versi minimum
  // didahulukan. Staf yang sudah masuk tetap bisa bekerja offline (rekam sesi tersimpan di HP).
  if (status != null && auth.phase != AuthPhase.ready) {
    if (status.maintenance) {
      return location == Routes.maintenance ? null : Routes.maintenance;
    }
    if (isOlderVersion(kAppVersion, status.minVersion)) {
      return location == Routes.update ? null : Routes.update;
    }
  }
  if (auth.phase != AuthPhase.signedOut) return authRedirect(auth, location);

  // Tujuan menurut tahap pasien; null = pasien sudah masuk.
  final target = switch (pasien.phase) {
    final p => pasienEntry(p),
  };
  final atLogin = location == Routes.login || location == Routes.forgotPassword || PRoutes.isPublic(location);

  if (target == null) {
    // Pasien sudah masuk: layar masuk & layar staf → beranda pasien.
    if (PRoutes.isPasien(location) && !PRoutes.isEntry(location)) return null;
    return PRoutes.beranda;
  }
  // Belum masuk: layar masuk/daftar/lupa password boleh tetap terbuka. Sudah daftar/masuk
  // (tahap hubungkan/persetujuan) → pindah ke layar tahapnya, jangan tertahan di halaman password.
  if (atLogin && target == Routes.login) return null;
  return location == target ? null : target;
}

/// Redirect go_router berdasarkan status login & peran (§3, §7).
/// Menu peran lain disembunyikan; membuka path-nya langsung dialihkan ke beranda peran aktif.
String? authRedirect(AuthState auth, String location) {
  String? only(String target) => location == target ? null : target;

  switch (auth.phase) {
    case AuthPhase.booting:
    case AuthPhase.needsConnection:
      return only(Routes.splash);
    case AuthPhase.sessionExpired:
      return only(Routes.sessionExpired);
    case AuthPhase.signedOut:
      return location == Routes.login || location == Routes.forgotPassword
          ? null
          : Routes.login;
    case AuthPhase.firstLogin:
      return only(Routes.firstLogin);
    case AuthPhase.chooseContext:
      return only(Routes.chooseContext);
    case AuthPhase.locked:
      return only(Routes.lock);
    case AuthPhase.ready:
      final role = auth.activeRole!;
      if (location == '/' || Routes._authPages.contains(location)) {
        return Routes.home(role);
      }
      if (location == klinikUserPath && role != Role.admin) {
        return Routes.klinikLainnya;
      }
      return null;
  }
}
