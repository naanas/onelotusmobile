import 'json.dart';

enum Gender {
  male('L', 'Laki-laki'),
  female('P', 'Perempuan');

  const Gender(this.api, this.label);
  final String api;
  final String label;

  static Gender? fromApi(Object? v) =>
      values.where((g) => g.api == v).firstOrNull;
}

/// Ringkasan paket aktif pasien (sisa kuota). Aturan paket ditentukan di workshop (§16).
class PackageSummary {
  const PackageSummary({
    required this.name,
    required this.remaining,
    required this.total,
    this.expiresAt,
  });

  final String name;
  final int remaining;
  final int total;
  final DateTime? expiresAt;

  /// Peringatan "paket hampir habis" (§5.3: warn bila ≤ 1).
  bool get almostEmpty => remaining <= 1;

  factory PackageSummary.fromJson(Map<String, dynamic> j) => PackageSummary(
    name: j['name'] as String,
    remaining: parseInt(j['remaining']) ?? 0,
    total: parseInt(j['total']) ?? 0,
    expiresAt: parseDate(j['expires_at']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'remaining': remaining,
    'total': total,
    'expires_at': formatDate(expiresAt),
  };
}

/// Data pasien — kolom tabel lama `data_pasiens` dipakai utuh (A.2).
/// [phone] & [address] null bila peran tidak berwenang (§7, §10); API yang menyaring.
class Patient {
  const Patient({
    required this.id,
    required this.number,
    required this.name,
    this.birthDate,
    this.birthPlace,
    this.phone,
    this.address,
    this.gender,
    this.institution,
    this.hobby,
    this.heightCm,
    this.weightKg,
    this.medicalAlert,
    this.activePackage,
    this.lastVisitAt,
  });

  final String id;

  /// Nomor pasien, tampil sebagai `#0412`.
  final int number;
  final String name;
  final DateTime? birthDate;
  final String? birthPlace;
  final String? phone;
  final String? address;
  final Gender? gender;

  /// `instansi` di sistem lama.
  final String? institution;

  /// `hobi` — tampil sebagai aktivitas di detail pasien (§5.3).
  final String? hobby;
  final double? heightCm;
  final double? weightKg;

  /// Peringatan medis dari riwayat, mis. "hindari tekanan kuat L4–L5" (§5.2).
  final String? medicalAlert;
  final PackageSummary? activePackage;
  final DateTime? lastVisitAt;

  int? ageOn(DateTime today) {
    final b = birthDate;
    if (b == null) return null;
    var age = today.year - b.year;
    if (today.month < b.month ||
        (today.month == b.month && today.day < b.day)) {
      age--;
    }
    return age;
  }

  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
    id: j['id'].toString(),
    number: parseInt(j['number']) ?? 0,
    name: j['name'] as String,
    birthDate: parseDate(j['birth_date']),
    birthPlace: j['birth_place'] as String?,
    phone: j['phone'] as String?,
    address: j['address'] as String?,
    gender: Gender.fromApi(j['gender']),
    institution: j['institution'] as String?,
    hobby: j['hobby'] as String?,
    heightCm: parseDouble(j['height_cm']),
    weightKg: parseDouble(j['weight_kg']),
    medicalAlert: j['medical_alert'] as String?,
    activePackage: j['active_package'] == null
        ? null
        : PackageSummary.fromJson(j['active_package'] as Map<String, dynamic>),
    lastVisitAt: parseDate(j['last_visit_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'name': name,
    'birth_date': formatDay(birthDate),
    'birth_place': birthPlace,
    'phone': phone,
    'address': address,
    'gender': gender?.api,
    'institution': institution,
    'hobby': hobby,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'medical_alert': medicalAlert,
    'active_package': activePackage?.toJson(),
    'last_visit_at': formatDate(lastVisitAt),
  };
}
