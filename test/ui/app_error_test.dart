import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/ui/feedback/app_error.dart';

void main() {
  test('fromApi memetakan format error seragam', () {
    final e = AppError.fromApi({
      'code': 'validation',
      'message': 'The bb must be a number.',
      'errors': {
        'bb': ['Berat badan harus angka, mis. 58'],
      },
      'ref': 'OL-7F3A',
    });
    expect(e.type, ErrorCode.validation);
    expect(e.kind, FeedbackKind.inline);
    expect(e.refId, 'OL-7F3A');
    expect(e.fieldError('bb'), 'Berat badan harus angka, mis. 58');
    expect(e.fieldError('tb'), isNull);
  });

  test('kode tak dikenal jadi unknown', () {
    expect(AppError.fromApi({'code': 'aneh'}).type, ErrorCode.unknown);
    expect(AppError.fromApi({}).type, ErrorCode.unknown);
  });

  test('template pesan diisi dari args', () {
    expect(
      const AppError(ErrorCode.syncFailed, args: {'n': 3}).message,
      '3 catatan belum terkirim.',
    );
    expect(
      const AppError(
        ErrorCode.pointsInsufficient,
        args: {'saldo': 240},
      ).message,
      'Poin belum cukup. Saldo: 240 poin.',
    );
  });

  test('katalog §12.4 lengkap & kode unik', () {
    final codes = ErrorCode.values.map((e) => e.code).toSet();
    expect(codes.length, ErrorCode.values.length);
    expect(codes.length, 26);
  });
}
