/// Model menu staf versi Laravel (Data Pasien, Pemeriksaan, Rekap, Formulir, User Management).
/// Nama field mengikuti Laravel; data dari `/v1/klinik/*` (tabel patients, pemeriksaan, bookings, staff).
library;

DateTime? _dt(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
String? _s(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
int? _i(Object? v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
num? _n(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);

/// 'L' → Laki-laki, 'P' → Perempuan.
String genderLabel(String? g) => switch (g?.trim().toUpperCase()) {
  'L' => 'Laki-laki',
  'P' => 'Perempuan',
  null || '' => '-',
  _ => g!,
};

/// 'L' / 'P' dari nilai apa pun.
String? genderCode(String? g) {
  final v = g?.trim().toUpperCase() ?? '';
  if (v == 'L' || v.startsWith('LAKI')) return 'L';
  if (v == 'P' || v.startsWith('PEREMPUAN')) return 'P';
  return null;
}

/// Angka tanpa ".0" (berat badan 60.0 → "60").
String fmtNum(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class KUser {
  const KUser({
    required this.id,
    required this.name,
    required this.username,
    required this.isAdmin,
    this.saya = false,
  });

  final String id;
  final String name;
  final String username;
  final bool isAdmin;

  /// Akun yang sedang dipakai (tidak bisa dihapus).
  final bool saya;

  String get roleLabel => isAdmin ? 'Admin' : 'Terapis';

  factory KUser.fromJson(Map<String, dynamic> j) => KUser(
    id: j['id'].toString(),
    name: j['name'] as String? ?? '',
    username: j['username'] as String? ?? '',
    isAdmin: j['role'] == 'admin',
    saya: j['saya'] == true,
  );
}

class Pasien {
  const Pasien({
    required this.id,
    required this.nama,
    required this.gender,
    this.nomor,
    this.ttl,
    this.tlp,
    this.alamat,
    this.instansi,
    this.hobi,
    this.tb,
    this.bb,
    this.tempatLahir,
    this.createdAt,
    this.kunjunganTerakhir,
    this.jumlahPemeriksaan = 0,
  });

  final String id;
  final int? nomor;
  final String nama;
  final DateTime? ttl;

  /// Hanya terisi untuk admin.
  final String? tlp;
  final String? alamat;
  final String gender;
  final String? instansi;
  final String? hobi;
  final num? tb;
  final num? bb;
  final String? tempatLahir;
  final DateTime? createdAt;
  final DateTime? kunjunganTerakhir;
  final int jumlahPemeriksaan;

  factory Pasien.fromJson(Map<String, dynamic> j) => Pasien(
    id: j['id'].toString(),
    nomor: _i(j['nomor']),
    nama: j['nama'] as String? ?? '',
    ttl: _dt(j['ttl']),
    tlp: _s(j['tlp']),
    alamat: _s(j['alamat']),
    gender: j['gender'] as String? ?? '',
    instansi: _s(j['instansi']),
    hobi: _s(j['hobi']),
    tb: _n(j['tb']),
    bb: _n(j['bb']),
    tempatLahir: _s(j['tempat_lahir']),
    createdAt: _dt(j['created_at']),
    kunjunganTerakhir: _dt(j['kunjungan_terakhir']),
    jumlahPemeriksaan: _i(j['jumlah_pemeriksaan']) ?? 0,
  );
}

/// Satu pemeriksaan (Laravel: perawatan).
class Pemeriksaan {
  const Pemeriksaan({
    required this.id,
    required this.pasienId,
    this.keluhan,
    this.penyebab,
    this.lamaCedera,
    this.analisa,
    this.treatment,
    this.bagianPenenang,
    this.kesimpulan,
    this.terapis,
    this.hasilRontgen,
    this.tanggal,
  });

  final int id;
  final String pasienId;
  final String? keluhan;
  final String? penyebab;
  final String? lamaCedera;
  final String? analisa;
  final String? treatment;
  final String? bagianPenenang;
  final String? kesimpulan;
  final String? terapis;
  final String? hasilRontgen;

  /// Tanggal pemeriksaan.
  final DateTime? tanggal;

  factory Pemeriksaan.fromJson(Map<String, dynamic> j) => Pemeriksaan(
    id: _i(j['id']) ?? 0,
    pasienId: j['pasien_id'].toString(),
    keluhan: _s(j['keluhan']),
    penyebab: _s(j['penyebab']),
    lamaCedera: _s(j['lama_cedera']),
    analisa: _s(j['analisa']),
    treatment: _s(j['treatment']),
    bagianPenenang: _s(j['bagian_penenang']),
    kesimpulan: _s(j['kesimpulan']),
    terapis: _s(j['terapis']),
    hasilRontgen: _s(j['hasil_rontgen']),
    tanggal: _dt(j['tgl_periksa']),
  );
}

/// Isian form tambah/edit pemeriksaan (juga isian awal dari Formulir).
class PemeriksaanDraft {
  const PemeriksaanDraft({
    this.keluhan,
    this.penyebab,
    this.lamaCedera,
    this.analisa,
    this.treatment,
    this.bagianPenenang,
    this.kesimpulan,
    this.terapis,
    this.hasilRontgen,
    this.tglPeriksa,
    this.bookingId,
  });

  final String? keluhan;
  final String? penyebab;
  final String? lamaCedera;
  final String? analisa;
  final String? treatment;
  final String? bagianPenenang;
  final String? kesimpulan;
  final String? terapis;
  final String? hasilRontgen;
  final DateTime? tglPeriksa;

  /// Formulir asal (dicatat di pemeriksaan).
  final String? bookingId;

  Map<String, dynamic> toJson() => {
    'keluhan': keluhan,
    'penyebab': penyebab,
    'lama_cedera': lamaCedera,
    'analisa': analisa,
    'treatment': treatment,
    'bagian_penenang': bagianPenenang,
    'kesimpulan': kesimpulan,
    'terapis': terapis,
    'hasil_rontgen': hasilRontgen,
    if (tglPeriksa != null) 'tgl_periksa': ymd(tglPeriksa!),
    if (bookingId != null) 'booking_id': bookingId,
  };
}

class PasienDetail {
  const PasienDetail(this.pasien, this.pemeriksaan);
  final Pasien pasien;
  final List<Pemeriksaan> pemeriksaan;
}

class PasienPage {
  const PasienPage(this.items, this.total, this.page, this.perPage);
  final List<Pasien> items;
  final int total;
  final int page;
  final int perPage;
  bool get hasMore => page * perPage < total;
}

/// Baris Rekap Data.
class RekapRow {
  const RekapRow({
    required this.pemeriksaanId,
    required this.pasienId,
    required this.nama,
    required this.gender,
    this.nomor,
    this.alamat,
    this.ttl,
    this.keluhan,
    this.analisa,
    this.treatment,
    this.bagianPenenang,
    this.terapis,
    this.tanggal,
  });

  final int pemeriksaanId;
  final String pasienId;
  final int? nomor;
  final String nama;
  final String gender;
  final DateTime? ttl;
  final String? alamat;
  final String? keluhan;
  final String? analisa;
  final String? treatment;
  final String? bagianPenenang;
  final String? terapis;
  final DateTime? tanggal;

  factory RekapRow.fromJson(Map<String, dynamic> j) => RekapRow(
    pemeriksaanId: _i(j['pemeriksaan_id']) ?? 0,
    pasienId: j['pasien_id'].toString(),
    nomor: _i(j['nomor']),
    nama: j['nama'] as String? ?? '',
    gender: j['gender'] as String? ?? '',
    ttl: _dt(j['ttl']),
    alamat: _s(j['alamat']),
    keluhan: _s(j['keluhan']),
    analisa: _s(j['analisa']),
    treatment: _s(j['treatment']),
    bagianPenenang: _s(j['bagian_penenang']),
    terapis: _s(j['terapis']),
    tanggal: _dt(j['tgl_periksa']),
  );
}

/// Isian keluhan dari formulir web / booking aplikasi.
class Intake {
  const Intake({
    this.keluhan,
    this.penyebab,
    this.lamaCedera,
    this.rontgen,
    this.catatan,
  });

  final String? keluhan;
  final String? penyebab;
  final String? lamaCedera;
  final String? rontgen;
  final String? catatan;

  factory Intake.fromJson(Map<String, dynamic>? j) => j == null
      ? const Intake()
      : Intake(
          keluhan: _s(j['keluhan']),
          penyebab: _s(j['penyebab']),
          lamaCedera: _s(j['lama_cedera']),
          rontgen: _s(j['rontgen']),
          catatan: _s(j['catatan']),
        );
}

/// Kiriman yang menunggu persetujuan terapis/admin (pengganti hasil Google Form di Laravel).
class Formulir {
  const Formulir({
    required this.id,
    required this.sumber,
    required this.status,
    required this.layanan,
    required this.lokasi,
    required this.pembayaran,
    required this.intake,
    this.dikirim,
    this.jadwal,
    this.total,
    this.pasien,
    this.tamu,
    this.fileRontgen = 0,
  });

  /// Id booking.
  final String id;

  /// website / patient_app.
  final String sumber;

  /// Status booking: pending / proposed (belum diterima) atau accepted (sudah terjadwal & dibayar).
  final String status;
  final DateTime? dikirim;
  final DateTime? jadwal;
  final String layanan;
  final String lokasi;

  /// lunas / tanpa_pembayaran.
  final String pembayaran;
  final int? total;
  final Pasien? pasien;
  final String? tamu;
  final Intake intake;
  final int fileRontgen;

  String get nama => pasien?.nama ?? tamu ?? '-';
  bool get dariAplikasi => sumber == 'patient_app';
  bool get menunggu => status == 'pending' || status == 'proposed';
  bool get lunas => pembayaran == 'lunas';
  bool get homeVisit => lokasi == 'home_visit';

  factory Formulir.fromJson(Map<String, dynamic> j) => Formulir(
    id: j['id'].toString(),
    sumber: j['sumber'] as String? ?? '',
    status: j['status'] as String? ?? '',
    dikirim: _dt(j['dikirim']),
    jadwal: _dt(j['jadwal']),
    layanan: j['layanan'] as String? ?? '',
    lokasi: j['lokasi'] as String? ?? 'clinic',
    pembayaran: j['pembayaran'] as String? ?? '',
    total: _i(j['total']),
    pasien: j['pasien'] is Map
        ? Pasien.fromJson((j['pasien'] as Map).cast<String, dynamic>())
        : null,
    tamu: _s(j['tamu']),
    intake: Intake.fromJson((j['intake'] as Map?)?.cast<String, dynamic>()),
    fileRontgen: _i(j['file_rontgen']) ?? 0,
  );
}

/// YYYY-MM-DD
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// YYYY-MM
String ym(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
