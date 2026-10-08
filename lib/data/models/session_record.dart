import 'json.dart';

/// Penyebab cedera (A.2: `penyebab` → pilihan + teks).
enum InjuryCause {
  sport('olahraga', 'Olahraga'),
  fall('jatuh', 'Jatuh'),
  work('kerja', 'Kerja / angkat beban'),
  accident('kecelakaan', 'Kecelakaan'),
  other('lainnya', 'Lainnya');

  const InjuryCause(this.api, this.label);
  final String api;
  final String label;

  static InjuryCause? fromApi(Object? v) =>
      values.where((c) => c.api == v).firstOrNull;
}

enum DurationUnit {
  day('hari'),
  week('minggu'),
  month('bulan'),
  year('tahun');

  const DurationUnit(this.label);
  final String label;

  static DurationUnit? fromApi(Object? v) =>
      values.where((u) => u.name == v).firstOrNull;
}

enum AttachmentKind { photo, xray, voice }

enum UploadState { pending, uploading, uploaded, failed }

/// Lampiran rekam sesi (AttachmentRow §4). Diunggah terpisah dari teks sesi (§8.5).
class Attachment {
  const Attachment({
    required this.id,
    required this.kind,
    this.localPath,
    this.remoteUrl,
    this.uploadState = UploadState.pending,
    this.progress = 0,
  });

  final String id;
  final AttachmentKind kind;
  final String? localPath;
  final String? remoteUrl;
  final UploadState uploadState;
  final double progress;

  /// Rontgen berlabel "Akses terbatas" (§4, §7).
  bool get restricted => kind == AttachmentKind.xray;

  Attachment copyWith({
    String? remoteUrl,
    UploadState? uploadState,
    double? progress,
  }) => Attachment(
    id: id,
    kind: kind,
    localPath: localPath,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    uploadState: uploadState ?? this.uploadState,
    progress: progress ?? this.progress,
  );

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
    id: j['id'].toString(),
    kind: AttachmentKind.values.byName(j['kind'] as String),
    localPath: j['local_path'] as String?,
    remoteUrl: j['url'] as String?,
    uploadState: UploadState.values.byName(
      j['upload_state'] as String? ?? 'uploaded',
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'local_path': localPath,
    'url': remoteUrl,
    'upload_state': uploadState.name,
  };
}

/// Rekam sesi / pemeriksaan (TR-04). Pemetaan kolom lama `perawatan` (A.2):
/// keluhan → [complaint], penyebab → [cause]+[causeNote], lama_cedera → [injuryDuration]+[injuryDurationUnit],
/// bagian → [treatedAreas], bagian_penenang → [calmingAreas], analisa → [analysis]+[analysisTags],
/// treatment → [treatments]+[treatmentNote], kesimpulan → [conclusion]+[conclusionTags],
/// terapis → [therapistId], hasil_rontgen → [attachments] (kind xray).
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.sessionId,
    required this.patientId,
    required this.therapistId,
    this.complaint = '',
    this.cause,
    this.causeNote,
    this.injuryDuration,
    this.injuryDurationUnit,
    this.treatedAreas = const [],
    this.calmingAreas = const [],
    this.painBefore,
    this.painAfter,
    this.analysis = '',
    this.analysisTags = const [],
    this.treatments = const [],
    this.treatmentNote = '',
    this.conclusion = '',
    this.conclusionTags = const [],
    this.attachments = const [],
    this.version = 0,
    this.updatedAt,
  });

  /// ID dibuat di HP (UUID) agar bisa disimpan offline sebelum ada ID server.
  final String id;
  final String sessionId;
  final String patientId;
  final String therapistId;
  final String complaint;
  final InjuryCause? cause;
  final String? causeNote;
  final int? injuryDuration;
  final DurationUnit? injuryDurationUnit;

  /// Kode area BodyMap: `slug:sisi`, mis. `lower-back:both`, `deltoids:right` (D.2b).
  final List<String> treatedAreas;
  final List<String> calmingAreas;

  /// Skala nyeri 0–10.
  final int? painBefore;
  final int? painAfter;

  /// Analisa terapis — catatan internal, tidak tampil di aplikasi pasien (§5.13).
  final String analysis;
  final List<String> analysisTags;
  final List<String> treatments;
  final String treatmentNote;
  final String conclusion;
  final List<String> conclusionTags;
  final List<Attachment> attachments;

  /// Versi server untuk deteksi konflik (§8.4). 0 = belum pernah tersimpan di server.
  final int version;
  final DateTime? updatedAt;

  /// Validasi lunak §5.2: area & minimal 1 treatment wajib.
  bool get isComplete => treatedAreas.isNotEmpty && treatments.isNotEmpty;

  SessionRecord copyWith({
    String? complaint,
    InjuryCause? cause,
    String? causeNote,
    int? injuryDuration,
    DurationUnit? injuryDurationUnit,
    List<String>? treatedAreas,
    List<String>? calmingAreas,
    int? painBefore,
    int? painAfter,
    String? analysis,
    List<String>? analysisTags,
    List<String>? treatments,
    String? treatmentNote,
    String? conclusion,
    List<String>? conclusionTags,
    List<Attachment>? attachments,
    int? version,
    DateTime? updatedAt,
  }) => SessionRecord(
    id: id,
    sessionId: sessionId,
    patientId: patientId,
    therapistId: therapistId,
    complaint: complaint ?? this.complaint,
    cause: cause ?? this.cause,
    causeNote: causeNote ?? this.causeNote,
    injuryDuration: injuryDuration ?? this.injuryDuration,
    injuryDurationUnit: injuryDurationUnit ?? this.injuryDurationUnit,
    treatedAreas: treatedAreas ?? this.treatedAreas,
    calmingAreas: calmingAreas ?? this.calmingAreas,
    painBefore: painBefore ?? this.painBefore,
    painAfter: painAfter ?? this.painAfter,
    analysis: analysis ?? this.analysis,
    analysisTags: analysisTags ?? this.analysisTags,
    treatments: treatments ?? this.treatments,
    treatmentNote: treatmentNote ?? this.treatmentNote,
    conclusion: conclusion ?? this.conclusion,
    conclusionTags: conclusionTags ?? this.conclusionTags,
    attachments: attachments ?? this.attachments,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Prefill §5.2 dari sesi sebelumnya: area, treatment, dan nyeri "sebelum" = "sesudah" sesi lalu.
  SessionRecord prefilledFrom(SessionRecord previous) => copyWith(
    complaint: complaint.isEmpty ? previous.complaint : complaint,
    cause: cause ?? previous.cause,
    causeNote: causeNote ?? previous.causeNote,
    injuryDuration: injuryDuration ?? previous.injuryDuration,
    injuryDurationUnit: injuryDurationUnit ?? previous.injuryDurationUnit,
    treatedAreas: treatedAreas.isEmpty ? previous.treatedAreas : treatedAreas,
    calmingAreas: calmingAreas.isEmpty ? previous.calmingAreas : calmingAreas,
    treatments: treatments.isEmpty ? previous.treatments : treatments,
    painBefore: painBefore ?? previous.painAfter,
  );

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
    id: j['id'].toString(),
    sessionId: j['session_id'].toString(),
    patientId: j['patient_id'].toString(),
    therapistId: j['therapist_id'].toString(),
    complaint: j['complaint'] as String? ?? '',
    cause: InjuryCause.fromApi(j['cause']),
    causeNote: j['cause_note'] as String?,
    injuryDuration: parseInt(j['injury_duration']),
    injuryDurationUnit: DurationUnit.fromApi(j['injury_duration_unit']),
    treatedAreas: parseStrings(j['treated_areas']),
    calmingAreas: parseStrings(j['calming_areas']),
    painBefore: parseInt(j['pain_before']),
    painAfter: parseInt(j['pain_after']),
    analysis: j['analysis'] as String? ?? '',
    analysisTags: parseStrings(j['analysis_tags']),
    treatments: parseStrings(j['treatments']),
    treatmentNote: j['treatment_note'] as String? ?? '',
    conclusion: j['conclusion'] as String? ?? '',
    conclusionTags: parseStrings(j['conclusion_tags']),
    attachments: [
      for (final a in (j['attachments'] as List?) ?? const [])
        Attachment.fromJson(a as Map<String, dynamic>),
    ],
    version: parseInt(j['version']) ?? 0,
    updatedAt: parseDate(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'patient_id': patientId,
    'therapist_id': therapistId,
    'complaint': complaint,
    'cause': cause?.api,
    'cause_note': causeNote,
    'injury_duration': injuryDuration,
    'injury_duration_unit': injuryDurationUnit?.name,
    'treated_areas': treatedAreas,
    'calming_areas': calmingAreas,
    'pain_before': painBefore,
    'pain_after': painAfter,
    'analysis': analysis,
    'analysis_tags': analysisTags,
    'treatments': treatments,
    'treatment_note': treatmentNote,
    'conclusion': conclusion,
    'conclusion_tags': conclusionTags,
    'attachments': [for (final a in attachments) a.toJson()],
    'version': version,
    'updated_at': formatDate(updatedAt),
  };
}

/// Catatan lama dari sistem Laravel (9 kolom teks), ditampilkan apa adanya (§5.3).
class LegacyRecord {
  const LegacyRecord({required this.date, required this.fields});

  final DateTime date;

  /// Label kolom → isi, urut seperti sistem lama.
  final Map<String, String> fields;

  factory LegacyRecord.fromJson(Map<String, dynamic> j) => LegacyRecord(
    date: parseDate(j['date']) ?? DateTime(1970),
    fields: {
      for (final e in ((j['fields'] as Map?) ?? const {}).entries)
        e.key.toString(): '${e.value ?? ''}',
    },
  );
}
