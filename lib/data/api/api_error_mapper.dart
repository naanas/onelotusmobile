import 'package:dio/dio.dart';

import '../../ui/feedback/app_error.dart';

/// Memetakan kegagalan HTTP ke [AppError] (§12.4, §12.7).
/// API Laravel mengembalikan `{ code, message, errors: {field: [...]}, ref }`.
AppError mapDioError(DioException e) {
  final res = e.response;
  final body = res?.data is Map
      ? (res!.data as Map).cast<String, dynamic>()
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
  // 409 konflik versi membawa salinan data server agar terapis bisa memilih (§8.4).
  if (status == 409 && body['server'] is Map) {
    final server = (body['server'] as Map).cast<String, dynamic>();
    return ConflictError(
      server: server,
      serverVersion: (server['version'] as num?)?.toInt() ?? 0,
      refId: ref,
    );
  }
  // 409 pasien ganda membawa kandidat untuk sheet ST-08.
  if (status == 409 &&
      body['code'] == 'duplicate_patient' &&
      body['candidates'] is List) {
    return DuplicatePatientError(
      candidates: [
        for (final c in body['candidates'] as List)
          (c as Map).cast<String, dynamic>(),
      ],
      refId: ref,
    );
  }
  // Kode eksplisit dari API menang (mis. 409 duplicate_patient / edit_conflict).
  final explicit = body['code'] as String?;
  if (explicit != null && ErrorCode.values.any((c) => c.code == explicit)) {
    return AppError.fromApi({...body, 'ref': ref});
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
    fieldErrors: {
      for (final f in ((body['errors'] as Map?) ?? const {}).entries)
        f.key.toString(): [
          for (final m in (f.value as List? ?? const [])) m.toString(),
        ],
    },
  );
}

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

/// `duplicate_patient` dengan daftar pasien mirip (`{ id, number, name, birth_date, match }`).
class DuplicatePatientError extends AppError {
  const DuplicatePatientError({required this.candidates, super.refId})
    : super(ErrorCode.duplicatePatient);

  final List<Map<String, dynamic>> candidates;
}
