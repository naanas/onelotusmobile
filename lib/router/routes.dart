import '../data/auth/auth_controller.dart';
import '../data/models/staff_user.dart';
import '../pasien/pasien_router.dart';
import '../pasien/pasien_routes.dart';
import '../pasien/pasien_session.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/lupa-password';
  static const firstLogin = '/login-pertama';
  static const chooseContext = '/pilih-peran';
  static const lock = '/kunci';
  static const sessionExpired = '/sesi-berakhir';
  static const devComponents = '/dev/komponen';

  /// Formulir pasien baru (WB-01): pindai QR KS-02, atau tautan `onelotus://app/intake/{kode}`.
  static const intakeScan = '/intake';
  static String intakeForm(String code) => '/intake/$code';
  static bool isIntake(String location) =>
      location == intakeScan || location.startsWith('$intakeScan/');

  // Terapis: Jadwal · Pasien · + · Riwayat · Akun
  static const terapisJadwal = '/terapis/jadwal';
  static const terapisPasien = '/terapis/pasien';
  static const terapisRiwayat = '/terapis/riwayat';
  static const terapisAkun = '/terapis/akun';
  static const terapisPilihPasien = '/terapis/pilih-pasien';
  static const terapisJadwalMinggu = '/terapis/jadwal-minggu';
  static String terapisRekam(String sessionId) => '/terapis/rekam/$sessionId';
  static String terapisSesi(String sessionId) => '/terapis/sesi/$sessionId';
  static String terapisHomeVisit(String sessionId) =>
      '/terapis/home-visit/$sessionId';
  static String terapisPasienDetail(String patientId) =>
      '/terapis/pasien/$patientId';
  static String terapisKirimLatihan(String patientId) =>
      '/terapis/pasien/$patientId/latihan';
  static const terapisAjukanCuti = '/terapis/cuti';
  static String terapisTagih(String sessionId) =>
      '/terapis/home-visit/$sessionId/tagih';
  static const terapisKas = '/terapis/kas';
  static const terapisKomisi = '/terapis/komisi';

  // Umum (semua peran)
  static const notifications = '/notifikasi';
  static const search = '/cari';
  static const syncStatus = '/status-sinkron';
  static const changePassword = '/ubah-password';
  static const notificationSettings = '/pengaturan-notifikasi';
  static const help = '/bantuan';
  static const update = '/perbarui';
  static const maintenance = '/pemeliharaan';

  // Kasir: Antrian · Pasien · + · Kasir · Akun
  static const kasirAntrian = '/kasir/antrian';
  static const kasirPasien = '/kasir/pasien';
  static const kasirKasir = '/kasir/kasir';
  static const kasirAkun = '/kasir/akun';
  static const _kasirTabs = {kasirAntrian, kasirPasien, kasirKasir, kasirAkun};
  static const kasirIntake = '/kasir/intake';
  static const kasirPasienForm = '/kasir/pasien-form';
  static String kasirPasienDetail(String id) => '/kasir/pasien/$id';
  static const kasirBuatJadwal = '/kasir/buat-jadwal';
  static const kasirBooking = '/kasir/booking';
  static const kasirPindahMassal = '/kasir/pindah-massal';
  static const kasirBayar = '/kasir/bayar';
  static const kasirStruk = '/kasir/struk';
  static const kasirJualPaket = '/kasir/jual-paket';
  static const kasirRiwayat = '/kasir/riwayat';
  static const kasirRefund = '/kasir/refund';
  static const kasirVerifikasiTransfer = '/kasir/verifikasi-transfer';
  static const kasirTerimaKas = '/kasir/terima-kas';
  static const kasirTutupKas = '/kasir/tutup-kas';
  static const kasirPiutang = '/kasir/piutang';

  // Owner: Ringkasan · Jadwal · Pasien · Laporan · Akun
  static const ownerRingkasan = '/owner/ringkasan';
  static const ownerJadwal = '/owner/jadwal';
  static const ownerPasien = '/owner/pasien';
  static const ownerLaporan = '/owner/laporan';
  static const ownerAkun = '/owner/akun';
  static const ownerEkspor = '/owner/ekspor'; // OW-05
  static const ownerPersetujuan = '/owner/persetujuan'; // OW-06
  static const ownerKomisi = '/owner/komisi'; // OW-07
  static const ownerStaf = '/owner/staf'; // OW-08
  static const ownerLayanan = '/owner/layanan'; // OW-09
  static const ownerPaket = '/owner/paket'; // OW-10
  static const ownerAturanKomisi = '/owner/aturan-komisi'; // OW-11
  static const ownerVoucher = '/owner/voucher'; // OW-12
  static const ownerPoin = '/owner/poin'; // OW-13
  static const ownerTemplate = '/owner/template'; // OW-14
  static const ownerPustaka = '/owner/pustaka'; // OW-15
  static const ownerPengumuman = '/owner/pengumuman'; // OW-16
  static const ownerCabang = '/owner/cabang'; // OW-17
  static const ownerAudit = '/owner/audit'; // OW-18
  static const ownerRekonsiliasi = '/owner/rekonsiliasi'; // OW-19
  static const ownerPengingat = '/owner/pengingat'; // OW-20

  static String home(Role role) => switch (role) {
    Role.terapis => terapisJadwal,
    Role.kasir => kasirAntrian,
    Role.owner => ownerRingkasan,
  };

  static String akun(Role role) => switch (role) {
    Role.terapis => terapisAkun,
    Role.kasir => kasirAkun,
    Role.owner => ownerAkun,
  };

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
String? appRedirect(AuthState auth, PasienSession pasien, String location) {
  // Formulir intake terbuka untuk siapa pun (pasien baru belum punya akun),
  // termasuk saat dibuka langsung dari QR ketika aplikasi baru dijalankan.
  if (Routes.isIntake(location)) return null;
  if (auth.phase != AuthPhase.signedOut) return authRedirect(auth, location);

  // Tujuan menurut tahap pasien; null = pasien sudah masuk.
  final target = switch (pasien.phase) {
    PasienPhase.otp when !pasien.awaitingCode => Routes.login,
    final p => pasienEntry(p),
  };
  final atLogin = location == Routes.login || location == Routes.forgotPassword;

  if (target == null) {
    // Pasien sudah masuk: layar masuk & layar staf → beranda pasien.
    if (PRoutes.isPasien(location) && !PRoutes.isEntry(location)) return null;
    return PRoutes.beranda;
  }
  if (atLogin && target != PRoutes.onboarding) return null;
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
      // Owner boleh membuka layar operasional kasir (piutang, buat jadwal,
      // pindah sesi), tapi tidak masuk ke tab kasir.
      if (role == Role.owner &&
          location.startsWith('/kasir/') &&
          !Routes._kasirTabs.contains(location)) {
        return null;
      }
      for (final other in Role.values) {
        if (other != role && location.startsWith('/${other.id}/')) {
          return Routes.home(role);
        }
      }
      return null;
  }
}
