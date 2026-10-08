/// Rute bagian pasien (ID layar = Lampiran A, PS-*). Semua berawalan `/pasien/`.
abstract final class PRoutes {
  static const onboarding = '/pasien/onboarding'; // PS-01
  static const masuk = '/pasien/masuk'; // PS-02
  static const hubungkan = '/pasien/hubungkan'; // PS-03
  static const persetujuan = '/pasien/persetujuan'; // PS-04

  // Tab: Beranda · Latihan · Booking · Profil (§4).
  static const beranda = '/pasien/beranda'; // PS-05
  static const latihan = '/pasien/latihan'; // PS-06
  static const booking = '/pasien/booking'; // PS-08
  static const profil = '/pasien/profil'; // PS-18

  static String latihanDetail(String id) => '/pasien/latihan/$id'; // PS-07
  static const bayar = '/pasien/bayar'; // PS-09
  static const jadwal = '/pasien/jadwal'; // PS-10
  static const ubahJadwal = '/pasien/jadwal/ubah'; // PS-11
  static const riwayat = '/pasien/riwayat'; // PS-12
  static const paket = '/pasien/paket'; // PS-13
  static const beliPaket = '/pasien/paket/beli'; // PS-14
  static const struk = '/pasien/struk'; // PS-15
  static const poin = '/pasien/poin'; // PS-16
  static const notifikasi = '/pasien/notifikasi'; // PS-17
  static const alamat = '/pasien/alamat'; // PS-19
  static const hapusAkun = '/pasien/hapus-akun'; // PS-20
  static const kebijakan = '/pasien/persetujuan-data'; // PS-04 dari Profil

  static const prefix = '/pasien/';
  static bool isPasien(String location) => location.startsWith(prefix);

  static const _entry = {onboarding, masuk, hubungkan, persetujuan};
  static bool isEntry(String location) => _entry.contains(location);
}
