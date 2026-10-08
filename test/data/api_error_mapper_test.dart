import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/api/api_error_mapper.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

DioException http(int status, [Map<String, dynamic>? body]) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: status, data: body),
  );
}

void main() {
  test('tanpa koneksi & timeout', () {
    final req = RequestOptions(path: '/x');
    expect(
      mapDioError(
        DioException(
          requestOptions: req,
          type: DioExceptionType.connectionError,
        ),
      ).type,
      ErrorCode.networkOffline,
    );
    expect(
      mapDioError(
        DioException(
          requestOptions: req,
          type: DioExceptionType.receiveTimeout,
        ),
      ).type,
      ErrorCode.networkTimeout,
    );
    expect(
      mapDioError(DioException(requestOptions: req)).type,
      ErrorCode.networkOffline,
    );
  });

  test('status HTTP → katalog §12.4', () {
    expect(mapDioError(http(401)).type, ErrorCode.authExpired);
    expect(mapDioError(http(403)).type, ErrorCode.forbidden);
    expect(mapDioError(http(404)).type, ErrorCode.notFound);
    expect(mapDioError(http(429)).type, ErrorCode.rateLimited);
    expect(mapDioError(http(503, {'ref': 'OL-7F3A'})).refId, 'OL-7F3A');
  });

  test('422 membawa pesan per field', () {
    final e = mapDioError(
      http(422, {
        'message': 'invalid',
        'errors': {
          'weight_kg': ['Berat badan harus angka, mis. 58'],
        },
      }),
    );
    expect(e.type, ErrorCode.validation);
    expect(e.fieldError('weight_kg'), 'Berat badan harus angka, mis. 58');
  });

  test('kode eksplisit dari API menang', () {
    expect(
      mapDioError(http(409, {'code': 'duplicate_patient'})).type,
      ErrorCode.duplicatePatient,
    );
  });

  test('409 dengan salinan server → ConflictError', () {
    final e = mapDioError(
      http(409, {
        'code': 'edit_conflict',
        'server': {'id': 'r1', 'version': 5},
      }),
    );
    expect(e, isA<ConflictError>());
    expect((e as ConflictError).serverVersion, 5);
  });

  test('yang boleh dicoba ulang otomatis', () {
    expect(isRetryable(const AppError(ErrorCode.serverError)), isTrue);
    expect(isRetryable(const AppError(ErrorCode.networkOffline)), isTrue);
    expect(isRetryable(const AppError(ErrorCode.validation)), isFalse);
    expect(isRetryable(const AppError(ErrorCode.forbidden)), isFalse);
  });
}
