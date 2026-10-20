import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/feedback/app_error.dart';

import '../api/api_client.dart';
import '../api/v1.dart';
import '../models/json.dart';
import '../models/models.dart';
import '../providers.dart';

/// Form intake pasien baru di aplikasi (WB-01): dibuka dari QR KS-02, tanpa login.
/// Endpoint publik `/v1/public/intake/{kode}`.
abstract interface class IntakeFormRepository {
  /// Nama cabang untuk judul form. Melempar `not_found` bila QR sudah tidak berlaku.
  Future<String> branchName(String code);

  /// Kirim isian → nomor antrian harian (mis. `A-07`). [clientId] sama = kiriman ulang aman.
  Future<IntakeReceipt> submit(String code, IntakeSubmission s);
}

final intakeFormRepositoryProvider = Provider<IntakeFormRepository>(
  (ref) => HttpIntakeFormRepository(ref.watch(apiClientProvider)),
);

/// Prefiks isi QR KS-02 (sama dengan backend `intakeLinkPrefix`).
const intakeLinkPrefix = 'onelotus://app/intake/';

/// Kode cabang dari isi QR (`onelotus://app/intake/{kode}`); null bila bukan QR intake One Lotus.
String? intakeCodeFromQr(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'onelotus') return null;
  final seg = uri.pathSegments;
  if (seg.length != 2 || seg[0] != 'intake' || seg[1].isEmpty) return null;
  return seg[1];
}

class IntakeReceipt {
  const IntakeReceipt({required this.queueLabel, required this.firstName});
  final String queueLabel;
  final String firstName;
}

/// Isian form intake (aturan sama dengan KS-04 + keluhan).
class IntakeSubmission {
  const IntakeSubmission({
    required this.clientId,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.phone,
    required this.complaint,
    required this.healthConsent,
    this.birthPlace,
    this.address,
    this.institution,
    this.hobby,
    this.heightCm,
    this.weightKg,
    this.cause,
    this.injuryDuration,
    this.injuryDurationUnit,
    this.photos = const [],
  });

  final String clientId;
  final String name;
  final DateTime birthDate;
  final Gender gender;
  final String phone;
  final String complaint;
  final bool healthConsent;
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

  /// Foto rontgen JPEG (sudah diperkecil saat dipilih), maks 3.
  final List<Uint8List> photos;

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'name': name,
    'birth_date': formatDay(birthDate),
    'gender': gender.api,
    'phone': phone,
    'complaint': complaint,
    'health_consent': healthConsent,
    'birth_place': ?birthPlace,
    'address': ?address,
    'institution': ?institution,
    'hobby': ?hobby,
    'height_cm': ?heightCm,
    'weight_kg': ?weightKg,
    'cause': ?cause?.api,
    'injury_duration': ?injuryDuration,
    if (injuryDuration != null) 'injury_duration_unit': injuryDurationUnit,
    'photos': [
      for (final p in photos)
        {'content_type': 'image/jpeg', 'data': base64Encode(p)},
    ],
  };
}

class HttpIntakeFormRepository implements IntakeFormRepository {
  HttpIntakeFormRepository(this.api);

  final ApiClient api;

  @override
  Future<String> branchName(String code) => api.get(
    '/v1/public/intake/${Uri.encodeComponent(code)}',
    (d) {
      final m = asMap(d);
      if ((m['policy_version'] as String?)?.isNotEmpty ?? false) {
        V1.policyVersion = m['policy_version'] as String;
      }
      return m['branch_name'] as String;
    },
  );

  /// Foto rontgen: minta tiket → PUT ke Supabase Storage → id lampiran (§12, maks 3).
  Future<String> _upload(String code, Uint8List bytes) async {
    final ticket = await api.post('/v1/public/intake/uploads', {
      'branch_token': code,
      'mime': 'image/jpeg',
      'size_bytes': bytes.length,
    }, asMap);
    try {
      await Dio().put<void>(
        ticket['upload_url'] as String,
        data: Stream.fromIterable([bytes]),
        options: Options(headers: {
          'Content-Type': 'image/jpeg',
          Headers.contentLengthHeader: bytes.length,
        }),
      );
    } on DioException catch (_) {
      throw const AppError(ErrorCode.uploadFailed);
    }
    return ticket['attachment_id'].toString();
  }

  @override
  Future<IntakeReceipt> submit(String code, IntakeSubmission s) async {
    final ids = [for (final p in s.photos.take(3)) await _upload(code, p)];
    return api.post(
      '/v1/public/intake',
      {
        'branch_token': code,
        'name': s.name,
        'birth_date': formatDay(s.birthDate),
        'gender': V1.genderApi(s.gender),
        'phone': s.phone,
        'complaint': s.complaint,
        'birth_place': s.birthPlace,
        'address': s.address,
        'occupation': s.institution,
        'hobby': s.hobby,
        'height_cm': s.heightCm,
        'weight_kg': s.weightKg,
        'cause': s.cause?.api,
        'injury_duration_value': s.injuryDuration,
        if (s.injuryDuration != null) 'injury_duration_unit': s.injuryDurationUnit,
        'xray_upload_ids': ids,
        'consent': {
          'policy_version': V1.policyVersion.isEmpty ? 'intake' : V1.policyVersion,
          'health_data': s.healthConsent,
          'reminders': true,
        },
      },
      (d) => IntakeReceipt(
        queueLabel: asMap(d)['queue_number'] as String,
        firstName: s.name.split(' ').first,
      ),
    );
  }
}
