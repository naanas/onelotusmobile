/// Rute aplikasi pasien (ID layar = Lampiran A, PS-*).
abstract final class PRoutes {
  static const onboarding = '/onboarding'; // PS-01
  static const masuk = '/masuk'; // PS-02
  static const hubungkan = '/hubungkan'; // PS-03
  static const persetujuan = '/persetujuan'; // PS-04

  // Tab: Beranda · Latihan · Booking · Profil (§4).
  static const beranda = '/beranda'; // PS-05
  static const latihan = '/latihan'; // PS-06
  static const booking = '/booking'; // PS-08
  static const profil = '/profil'; // PS-18

  static String latihanDetail(String id) => '/latihan/$id'; // PS-07
  static const bayar = '/bayar'; // PS-09
  static const jadwal = '/jadwal'; // PS-10
  static const ubahJadwal = '/jadwal/ubah'; // PS-11
  static const riwayat = '/riwayat'; // PS-12
  static const paket = '/paket'; // PS-13
  static const beliPaket = '/paket/beli'; // PS-14
  static const struk = '/struk'; // PS-15
  static const poin = '/poin'; // PS-16
  static const notifikasi = '/notifikasi'; // PS-17
  static const alamat = '/alamat'; // PS-19
  static const hapusAkun = '/hapus-akun'; // PS-20
  static const kebijakan = '/persetujuan-data'; // PS-04 dari Profil

  static const _entry = {onboarding, masuk, hubungkan, persetujuan};
  static bool isEntry(String location) => _entry.contains(location);
}
