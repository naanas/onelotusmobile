import 'package:dio/dio.dart';

import '../../ui/feedback/app_error.dart';

/// Memetakan kegagalan HTTP ke [AppError] (§12.4, §12.7).
/// One Lotus API v1 mengembalikan `{ "error": { code, message, fields: {field: pesan}, details, ref } }`.
AppError mapDioError(DioException e) {
  final res = e.response;
  final raw = res?.data is Map
      ? (res!.data as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  final body = raw['error'] is Map
      ? (raw['error'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  final details = body['details'] is Map
      ? (body['details'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  final ref = body['ref'] as String? ?? res?.headers.value('x-request-ref');

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const AppError(ErrorCode.networkTimeout);
    case DioExceptionType.connectionError:
      return const AppError(ErrorCode.networkOffline);
    case DioExceptionType.unknown when res == null:
      // SocketException dll. tanpa respons → anggap offline.
      return const AppError(ErrorCode.networkOffline);
    default:
      break;
  }

  final status = res?.statusCode ?? 0;
  final code = body['code'] as String?;
  // 409 edit_conflict membawa versi server (`details.server`) agar terapis bisa memilih (§9.4, ST-09).
  if (status == 409 && code == 'edit_conflict') {
    final server = details['server'] is Map
        ? (details['server'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return ConflictError(
      server: server,
      serverVersion:
          (server['version'] as num?)?.toInt() ??
          (details['server_version'] as num?)?.toInt() ??
          0,
      refId: ref,
    );
  }
  // 409 pasien ganda membawa kandidat untuk sheet ST-08.
  if (status == 409 && code == 'duplicate_patient') {
    return DuplicatePatientError(
      candidates: [
        for (final c in (details['candidates'] as List?) ?? const [])
          (c as Map).cast<String, dynamic>(),
      ],
      refId: ref,
    );
  }
  final fields = {
    for (final f in ((body['fields'] as Map?) ?? const {}).entries)
      f.key.toString(): [f.value.toString()],
  };
  // Kode eksplisit dari API menang bila dikenal aplikasi.
  if (code != null && ErrorCode.values.any((c) => c.code == code)) {
    return AppError(
      ErrorCode.fromCode(code),
      refId: ref,
      fieldErrors: fields,
      args: _args(code, details),
      apiCode: code,
      apiMessage: body['message'] as String?,
      details: details,
    );
  }
  final type = switch (status) {
    401 => ErrorCode.authExpired,
    403 => ErrorCode.forbidden,
    404 => ErrorCode.notFound,
    409 => ErrorCode.editConflict,
    422 => ErrorCode.validation,
    429 => ErrorCode.rateLimited,
    >= 500 => ErrorCode.serverError,
    _ => ErrorCode.unknown,
  };
  return AppError(
    type,
    refId: ref,
    fieldErrors: fields,
    apiCode: code,
    apiMessage: body['message'] as String?,
    details: details,
  );
}

Map<String, Object> _args(String code, Map<String, dynamic> d) => switch (code) {
  'checkin_out_of_range' => {
    if (d['distance_m'] != null) 'jarak': '${d['distance_m']} m',
  },
  _ => const {},
};

/// Error yang layak dicoba ulang otomatis oleh outbox (§8.2).
bool isRetryable(AppError e) => switch (e.type) {
  ErrorCode.networkOffline ||
  ErrorCode.networkTimeout ||
  ErrorCode.serverError ||
  ErrorCode.rateLimited => true,
  _ => false,
};

/// `edit_conflict` dengan isi versi server.
class ConflictError extends AppError {
  const ConflictError({
    required this.server,
    required this.serverVersion,
    super.refId,
  }) : super(ErrorCode.editConflict);

  final Map<String, dynamic> server;
  final int serverVersion;
}

/// `duplicate_patient` dengan daftar pasien mirip (`{ id, number, name, match_on }`).
class DuplicatePatientError extends AppError {
  const DuplicatePatientError({required this.candidates, super.refId})
    : super(ErrorCode.duplicatePatient);

  final List<Map<String, dynamic>> candidates;
}
