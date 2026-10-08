import '../data/auth/auth_controller.dart';
import '../data/models/staff_user.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/lupa-password';
  static const firstLogin = '/login-pertama';
  static const chooseContext = '/pilih-peran';
  static const lock = '/kunci';
  static const sessionExpired = '/sesi-berakhir';
  static const devComponents = '/dev/komponen';

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
      for (final other in Role.values) {
        if (other != role && location.startsWith('/${other.id}/')) {
          return Routes.home(role);
        }
      }
      return null;
  }
}
