/// Model data — kolom mengikuti tabel Laravel lama (data_pasiens, perawatan, users, Google Form).
library;

DateTime? _dt(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
String? _s(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
int? _i(Object? v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

/// Peran: admin (lihat nomor HP & kelola user) atau user (terapis).
enum Role {
  admin('Admin'),
  user('Terapis');

  const Role(this.label);
  final String label;

  static Role parse(Object? v) => v == 'admin' ? Role.admin : Role.user;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
  });

  final int id;
  final String name;
  final String username;
  final Role role;

  bool get isAdmin => role == Role.admin;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: _i(j['id']) ?? 0,
    name: j['name'] as String? ?? '',
    username: j['username'] as String? ?? '',
    role: Role.parse(j['role']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'role': role.name,
  };
}

/// 'L' → Laki-laki, 'P' → Perempuan, selain itu apa adanya (data lama).
String genderLabel(String? g) => switch (g?.trim().toUpperCase()) {
  'L' => 'Laki-laki',
  'P' => 'Perempuan',
  null || '' => '-',
  _ => g!,
};

/// 'L' / 'P' dari nilai apa pun (data lama ada yang 'Laki - Laki').
String? genderCode(String? g) {
  final v = g?.trim().toUpperCase() ?? '';
  if (v == 'L' || v.startsWith('LAKI')) return 'L';
  if (v == 'P' || v.startsWith('PEREMPUAN')) return 'P';
  return null;
}

class Pasien {
  const Pasien({
    required this.id,
    required this.nomor,
    required this.nama,
    required this.ttl,
    required this.alamat,
    required this.gender,
    required this.instansi,
    this.tlp,
    this.agama,
    this.hobi,
    this.tb,
    this.bb,
    this.tempatLahir,
    this.createdAt,
    this.kunjunganTerakhir,
    this.jumlahPemeriksaan = 0,
  });

  final int id;
  final int nomor;
  final String nama;
  final DateTime? ttl;

  /// Hanya terisi untuk admin.
  final String? tlp;
  final String alamat;
  final String? agama;
  final String gender;
  final String instansi;
  final String? hobi;
  final int? tb;
  final int? bb;
  final String? tempatLahir;
  final DateTime? createdAt;
  final DateTime? kunjunganTerakhir;
  final int jumlahPemeriksaan;

  factory Pasien.fromJson(Map<String, dynamic> j) => Pasien(
    id: _i(j['id']) ?? 0,
    nomor: _i(j['nomor']) ?? 0,
    nama: j['nama'] as String? ?? '',
    ttl: _dt(j['ttl']),
    tlp: _s(j['tlp']),
    alamat: j['alamat'] as String? ?? '',
    agama: _s(j['agama']),
    gender: j['gender'] as String? ?? '',
    instansi: j['instansi'] as String? ?? '',
    hobi: _s(j['hobi']),
    tb: _i(j['tb']),
    bb: _i(j['bb']),
    tempatLahir: _s(j['tempat_lahir']),
    createdAt: _dt(j['created_at']),
    kunjunganTerakhir: _dt(j['kunjungan_terakhir']),
    jumlahPemeriksaan: _i(j['jumlah_pemeriksaan']) ?? 0,
  );
}

/// Satu pemeriksaan (tabel perawatan).
class Perawatan {
  const Perawatan({
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
  final int pasienId;
  final String? keluhan;
  final String? penyebab;
  final String? lamaCedera;
  final String? analisa;
  final String? treatment;
  final String? bagianPenenang;
  final String? kesimpulan;
  final String? terapis;
  final String? hasilRontgen;

  /// created_at = tanggal pemeriksaan.
  final DateTime? tanggal;

  factory Perawatan.fromJson(Map<String, dynamic> j) => Perawatan(
    id: _i(j['id']) ?? 0,
    pasienId: _i(j['data_pasien_id']) ?? 0,
    keluhan: _s(j['keluhan']),
    penyebab: _s(j['penyebab']),
    lamaCedera: _s(j['lama_cedera']),
    analisa: _s(j['analisa']),
    treatment: _s(j['treatment']),
    bagianPenenang: _s(j['bagian_penenang']),
    kesimpulan: _s(j['kesimpulan']),
    terapis: _s(j['terapis']),
    hasilRontgen: _s(j['hasil_rontgen']),
    tanggal: _dt(j['created_at']),
  );
}

/// Isian form tambah/edit pemeriksaan (juga dipakai untuk prefill dari Formulir).
class PerawatanDraft {
  const PerawatanDraft({
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
  };
}

class PasienDetail {
  const PasienDetail(this.pasien, this.perawatan);
  final Pasien pasien;
  final List<Perawatan> perawatan;
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
    required this.perawatanId,
    required this.pasienId,
    required this.nomor,
    required this.nama,
    required this.gender,
    required this.alamat,
    this.ttl,
    this.keluhan,
    this.analisa,
    this.treatment,
    this.bagianPenenang,
    this.terapis,
    this.tanggal,
  });

  final int perawatanId;
  final int pasienId;
  final int nomor;
  final String nama;
  final String gender;
  final DateTime? ttl;
  final String alamat;
  final String? keluhan;
  final String? analisa;
  final String? treatment;
  final String? bagianPenenang;
  final String? terapis;
  final DateTime? tanggal;

  factory RekapRow.fromJson(Map<String, dynamic> j) => RekapRow(
    perawatanId: _i(j['perawatan_id']) ?? 0,
    pasienId: _i(j['pasien_id']) ?? 0,
    nomor: _i(j['nomor']) ?? 0,
    nama: j['nama'] as String? ?? '',
    gender: j['gender'] as String? ?? '',
    ttl: _dt(j['ttl']),
    alamat: j['alamat'] as String? ?? '',
    keluhan: _s(j['keluhan']),
    analisa: _s(j['analisa']),
    treatment: _s(j['treatment']),
    bagianPenenang: _s(j['bagian_penenang']),
    terapis: _s(j['terapis']),
    tanggal: _dt(j['created_at']),
  );
}

/// Satu kiriman form pendaftaran (pengganti baris Google Sheet).
class Formulir {
  const Formulir({
    required this.id,
    required this.timestamp,
    required this.nama,
    required this.alamat,
    required this.jenisKelamin,
    required this.sudahDitambahkan,
    this.tempatLahir,
    this.tanggalLahir,
    this.nomorTelepon,
    this.instansi,
    this.beratBadan,
    this.tinggiBadan,
    this.hobi,
    this.keluhan,
    this.penyebabCedera,
    this.lamaCedera,
    this.rontgen,
    this.pasienId,
  });

  final int id;
  final String timestamp;
  final String nama;
  final String alamat;
  final String? tempatLahir;
  final DateTime? tanggalLahir;
  final String? nomorTelepon;
  final String jenisKelamin;
  final String? instansi;
  final int? beratBadan;
  final int? tinggiBadan;
  final String? hobi;
  final String? keluhan;
  final String? penyebabCedera;
  final String? lamaCedera;
  final String? rontgen;
  final bool sudahDitambahkan;
  final int? pasienId;

  factory Formulir.fromJson(Map<String, dynamic> j) => Formulir(
    id: _i(j['id']) ?? 0,
    timestamp: j['timestamp'] as String? ?? '',
    nama: j['nama'] as String? ?? '',
    alamat: j['alamat'] as String? ?? '',
    tempatLahir: _s(j['tempat_lahir']),
    tanggalLahir: _dt(j['tanggal_lahir']),
    nomorTelepon: _s(j['nomor_telepon']),
    jenisKelamin: j['jenis_kelamin'] as String? ?? '',
    instansi: _s(j['instansi']),
    beratBadan: _i(j['berat_badan']),
    tinggiBadan: _i(j['tinggi_badan']),
    hobi: _s(j['hobi']),
    keluhan: _s(j['keluhan']),
    penyebabCedera: _s(j['penyebab_cedera']),
    lamaCedera: _s(j['lama_cedera']),
    rontgen: _s(j['rontgen']),
    sudahDitambahkan: j['sudah_ditambahkan'] == true,
    pasienId: _i(j['data_pasien_id']),
  );
}

/// YYYY-MM-DD
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// YYYY-MM
String ym(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
