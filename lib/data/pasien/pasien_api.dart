import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/json.dart';
import '../models/models.dart';

/// Endpoint pasien `/v1/pasien/*` (token pasien terpisah dari token staf). Kontrak: docs/api-kontrak.md.
class PasienApi {
  PasienApi(this.api);

  final ApiClient api;

  /// Kirim kode OTP WhatsApp → detik sampai boleh kirim ulang.
  Future<int> requestOtp(String phone) => api.post('/v1/pasien/otp', {
    'phone': phone,
  }, (d) => parseInt(asMap(d)['resend_in']) ?? 60);

  Future<(String token, PasienAccount account)> verifyOtp(
    String phone,
    String code,
  ) => api.post(
    '/v1/pasien/otp/verify',
    {'phone': phone, 'code': code, 'device_name': 'onelotus-pasien'},
    (d) {
      final m = asMap(d);
      return (
        m['token'] as String,
        PasienAccount.fromJson(asMap(m['account'])),
      );
    },
  );

  Future<PasienAccount> me() =>
      api.get('/v1/pasien/me', (d) => PasienAccount.fromJson(asMap(d)));

  Future<void> logout() => api.post('/v1/pasien/logout', null, (_) {});

  Future<LinkCandidates> linkCandidates() => api.get(
    '/v1/pasien/link-candidates',
    (d) => LinkCandidates.fromJson(asMap(d)),
  );

  Future<PasienAccount> link({
    String? patientId,
    required DateTime birthDate,
  }) => api.post('/v1/pasien/link', {
    'patient_id': ?patientId,
    'birth_date': formatDay(birthDate),
  }, (d) => PasienAccount.fromJson(asMap(d)));

  Future<PasienAccount> register(PatientDraft draft) => api.post(
    '/v1/pasien/register',
    draft.toJson(),
    (d) => PasienAccount.fromJson(asMap(d)),
  );

  Future<PasienAccount> consent({required bool promo}) => api.post(
    '/v1/pasien/consent',
    {'health': true, 'reminder': true, 'promo': promo},
    (d) => PasienAccount.fromJson(asMap(d)),
  );

  Future<List<PasienSessionItem>> sessions({bool past = false}) => api.get(
    '/v1/pasien/sessions',
    (d) => parseList(d, PasienSessionItem.fromJson),
    query: {'scope': past ? 'past' : 'upcoming'},
  );

  Future<int> requestDeletionOtp() => api.post(
    '/v1/pasien/account/deletion-otp',
    null,
    (d) => parseInt(asMap(d)['resend_in']) ?? 60,
  );

  Future<void> requestDeletion(String code) =>
      api.post('/v1/pasien/account/deletion', {'code': code}, (_) {});
}

/// Token pasien saat ini (diisi `PasienSessionNotifier`).
final pasienTokenProvider = NotifierProvider<PasienTokenNotifier, String?>(
  PasienTokenNotifier.new,
);

class PasienTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? token) => state = token;
}
