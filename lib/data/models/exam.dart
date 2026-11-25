import 'json.dart';

/// Pemeriksaan pasien (seperti tabel `perawatan` di sistem Laravel lama): catatan hasil impor + input baru
/// dari terapis/admin. Semua kolom teks bebas, sama dengan form pemeriksaan Laravel.
class ExamV {
  const ExamV({
    required this.id,
    this.date,
    this.complaint,
    this.cause,
    this.injuryDuration,
    this.analysis,
    this.treatment,
    this.calmingArea,
    this.conclusion,
    this.therapistName,
    this.xray,
  });

  final int id;
  final DateTime? date;
  final String? complaint, cause, injuryDuration, analysis, treatment, calmingArea, conclusion, therapistName, xray;

  static String? _s(Object? v) {
    final t = v?.toString().trim();
    return t == null || t.isEmpty ? null : t;
  }

  factory ExamV.fromJson(Map<String, dynamic> j) => ExamV(
    id: parseInt(j['id']) ?? 0,
    date: parseDate(j['record_date']),
    complaint: _s(j['complaint']),
    cause: _s(j['cause']),
    injuryDuration: _s(j['injury_duration']),
    analysis: _s(j['analysis']),
    treatment: _s(j['treatment']),
    calmingArea: _s(j['calming_area']),
    conclusion: _s(j['conclusion']),
    therapistName: _s(j['therapist_name']),
    xray: _s(j['xray_url'] ?? j['xray_note']),
  );

  /// Label → isi untuk tampilan (urut seperti form Laravel), hanya yang terisi.
  Map<String, String> get fields => {
    if (complaint != null) 'Keluhan': complaint!,
    if (cause != null) 'Penyebab': cause!,
    if (injuryDuration != null) 'Lama cedera': injuryDuration!,
    if (analysis != null) 'Analisa': analysis!,
    if (treatment != null) 'Treatment': treatment!,
    if (calmingArea != null) 'Bagian penenang': calmingArea!,
    if (conclusion != null) 'Kesimpulan': conclusion!,
    if (xray != null) 'Hasil rontgen': xray!,
  };
}
