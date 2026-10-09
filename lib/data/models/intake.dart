import 'json.dart';
import 'patient.dart';

/// Status kiriman form intake QR (WB-01 → KS-02).
enum IntakeStatus {
  pending('new'),
  processed('processed'),
  discarded('discarded');

  const IntakeStatus(this.api);
  final String api;

  static IntakeStatus fromApi(Object? v) =>
      values.where((s) => s.api == v).firstOrNull ?? IntakeStatus.pending;
}

/// Penyebab keluhan di form intake (berbeda dari rekam sesi: ada "Tidak tahu").
enum IntakeCause {
  olahraga('olahraga', 'Olahraga'),
  jatuh('jatuh', 'Jatuh'),
  kerja('kerja', 'Kerja / posisi duduk'),
  kecelakaan('kecelakaan', 'Kecelakaan'),
  tidakTahu('tidak_tahu', 'Tidak tahu');

  const IntakeCause(this.api, this.label);
  final String api;
  final String label;

  static IntakeCause? fromApi(Object? v) =>
      values.where((c) => c.api == v).firstOrNull;
}

/// Satu baris "Baru masuk" di KS-02.
class IntakeSummary {
  const IntakeSummary({
    required this.id,
    required this.queueLabel,
    required this.name,
    required this.complaint,
    required this.bodyComplete,
    required this.attachmentCount,
    required this.status,
    required this.stale,
    required this.createdAt,
    this.patientId,
  });

  final String id;

  /// Nomor antrian harian, mis. `A-07`.
  final String queueLabel;
  final String name;
  final String complaint;

  /// TB & BB terisi.
  final bool bodyComplete;
  final int attachmentCount;
  final IntakeStatus status;

  /// Belum diproses > 24 jam (ditandai merah).
  final bool stale;
  final DateTime createdAt;
  final String? patientId;

  factory IntakeSummary.fromJson(Map<String, dynamic> j) => IntakeSummary(
    id: j['id'] as String,
    queueLabel: j['queue_label'] as String? ?? '',
    name: j['name'] as String,
    complaint: j['complaint'] as String? ?? '',
    bodyComplete: j['body_complete'] as bool? ?? false,
    attachmentCount: parseInt(j['attachment_count']) ?? 0,
    status: IntakeStatus.fromApi(j['status']),
    stale: j['stale'] as bool? ?? false,
    createdAt: parseDate(j['created_at']) ?? DateTime.now(),
    patientId: j['patient_id']?.toString(),
  );
}

class IntakeAttachment {
  const IntakeAttachment({required this.id, required this.contentType});
  final String id;
  final String contentType;
}

/// Isian lengkap kiriman intake — dipakai mengisi form verifikasi KS-04.
class IntakeDetail {
  const IntakeDetail({
    required this.summary,
    required this.birthDate,
    required this.gender,
    required this.phone,
    this.birthPlace,
    this.address,
    this.institution,
    this.hobby,
    this.heightCm,
    this.weightKg,
    this.cause,
    this.injuryDuration,
    this.injuryDurationUnit,
    this.attachments = const [],
  });

  final IntakeSummary summary;
  final DateTime birthDate;
  final Gender gender;
  final String phone;
  final String? birthPlace;
  final String? address;
  final String? institution;
  final String? hobby;
  final int? heightCm;
  final int? weightKg;
  final IntakeCause? cause;
  final int? injuryDuration;

  /// `day` | `week` | `month`
  final String? injuryDurationUnit;
  final List<IntakeAttachment> attachments;

  String get id => summary.id;

  /// Lama keluhan untuk ditampilkan, mis. "2 minggu".
  String? get durationLabel {
    final n = injuryDuration;
    if (n == null) return null;
    final unit = switch (injuryDurationUnit) {
      'day' => 'hari',
      'month' => 'bulan',
      _ => 'minggu',
    };
    return '$n $unit';
  }

  factory IntakeDetail.fromJson(Map<String, dynamic> j) => IntakeDetail(
    summary: IntakeSummary.fromJson(j),
    birthDate: parseDate(j['birth_date']) ?? DateTime(2000),
    gender: Gender.fromApi(j['gender']) ?? Gender.female,
    phone: j['phone'] as String? ?? '',
    birthPlace: j['birth_place'] as String?,
    address: j['address'] as String?,
    institution: j['institution'] as String?,
    hobby: j['hobby'] as String?,
    heightCm: parseInt(j['height_cm']),
    weightKg: parseInt(j['weight_kg']),
    cause: IntakeCause.fromApi(j['cause']),
    injuryDuration: parseInt(j['injury_duration']),
    injuryDurationUnit: j['injury_duration_unit'] as String?,
    attachments: [
      for (final a in (j['attachments'] as List?) ?? const [])
        IntakeAttachment(
          id: (a as Map)['id'] as String,
          contentType: a['content_type'] as String? ?? 'image/jpeg',
        ),
    ],
  );
}

/// Isian KS-04 hasil koreksi kasir, dikirim saat verifikasi (atau tambah pasien manual).
class PatientDraft {
  const PatientDraft({
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.phone,
    this.birthPlace,
    this.address,
    this.institution,
    this.hobby,
    this.heightCm,
    this.weightKg,
    this.initialComplaint,
    this.healthConsent = false,
  });

  final String name;
  final DateTime birthDate;
  final Gender gender;
  final String phone;
  final String? birthPlace;
  final String? address;
  final String? institution;
  final String? hobby;
  final int? heightCm;
  final int? weightKg;
  final String? initialComplaint;
  final bool healthConsent;

  Map<String, dynamic> toJson() => {
    'name': name,
    'birth_date': formatDay(birthDate),
    'gender': gender.api,
    'phone': phone,
    'birth_place': birthPlace,
    'address': address,
    'institution': institution,
    'hobby': hobby,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'initial_complaint': initialComplaint,
    'health_consent': healthConsent,
  };
}

/// Tautan QR intake cabang (`{ code, url }`).
class IntakeLink {
  const IntakeLink({required this.code, required this.url});
  final String code;
  final String url;

  factory IntakeLink.fromJson(Map<String, dynamic> j) =>
      IntakeLink(code: j['code'] as String, url: j['url'] as String);
}
