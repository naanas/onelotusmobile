import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/feedback/app_error.dart';
import '../api/api_client.dart';
import '../api/v1.dart';
import '../models/json.dart';
import '../models/models.dart';

/// Endpoint pasien One Lotus API v1: `/v1/auth/patient/*` (OTP WhatsApp) dan `/v1/patient/*`.
/// Token pasien terpisah dari token staf.
class PasienApi {
  PasienApi(this.api, {required this.deviceId});

  final ApiClient api;
  final Future<String> Function() deviceId;

  /// Kandidat data lama dari verifikasi OTP terakhir (dipakai layar hubungkan PS-03).
  LinkCandidates _candidates = const LinkCandidates(candidates: [], locked: false, attemptsLeft: 3);
  String _phone = '';

  /// Kirim kode OTP WhatsApp → detik sampai boleh kirim ulang.
  /// [purpose]: `register` (daftar akun) atau `reset_password` (lupa password).
  Future<int> requestOtp(String phone, {String purpose = 'register'}) async {
    try {
      await api.post('/v1/auth/patient/otp', {'phone': phone, 'purpose': purpose}, (_) {});
      return 60;
    } on AppError catch (e) {
      // Kode masih berlaku: tampilkan sisa waktu kirim ulang.
      if (e.type == ErrorCode.rateLimited && e.details['retry_after_sec'] is num) {
        return (e.details['retry_after_sec'] as num).toInt();
      }
      rethrow;
    }
  }

  /// Cek kode OTP (daftar / lupa password) → token verifikasi (berlaku 15 menit). Kode hangus setelah benar.
  Future<String> verifyCode(String phone, String purpose, String code) => api.post(
    '/v1/auth/patient/otp/verify',
    {'phone': phone, 'purpose': purpose, 'code': code},
    (d) => asMap(d)['verification_token'] as String,
  );

  /// Daftar akun: token verifikasi (purpose=register) + password baru → token + akun.
  Future<(String token, String refresh, PasienAccount account)> register(String phone, String verification, String password) async =>
      _session(phone, await api.post('/v1/auth/patient/register', {
        'phone': phone,
        'verification_token': verification,
        'password': password,
        'device_id': await deviceId(),
        'platform': 'android',
      }, asMap));

  /// Masuk: nomor HP + password → token + akun.
  Future<(String token, String refresh, PasienAccount account)> login(String phone, String password) async =>
      _session(phone, await api.post('/v1/auth/patient/login', {
        'phone': phone,
        'password': password,
        'device_id': await deviceId(),
        'platform': 'android',
      }, asMap));

  /// Lupa password: token verifikasi (purpose=reset_password) + password baru. Sesi lain dicabut.
  Future<void> resetPassword(String phone, String verification, String password) => api.post(
    '/v1/auth/patient/password/reset',
    {'phone': phone, 'verification_token': verification, 'password': password},
    (_) {},
  );

  Future<(String, String, PasienAccount)> _session(String phone, Map<String, dynamic> m) async {
    final tokens = asMap(m['tokens']);
    final access = tokens['access_token'] as String;
    _phone = phone;
    _candidates = LinkCandidates(
      candidates: [
        for (final c in (m['candidates'] as List? ?? const []))
          LinkCandidate(id: asMap(c)['candidate_id'] as String, maskedName: asMap(c)['masked_name'] as String),
      ],
      locked: false,
      attemptsLeft: 3,
    );
    final account = await me(token: access);
    return (access, tokens['refresh_token'] as String, account);
  }

  /// Tukar refresh token pasien; null bila ditolak.
  Future<(String, String)?> refresh(String refreshToken) async {
    try {
      final m = await api.dio.post<dynamic>('/v1/auth/refresh', data: {'refresh_token': refreshToken});
      final d = asMap(ApiClient.unwrap(m.data));
      return (d['access_token'] as String, d['refresh_token'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Akun: data pasien tertaut + persetujuan → tahap berikut (hubungkan / persetujuan / siap).
  Future<PasienAccount> me({String? token}) async {
    final headers = token == null ? null : {'Authorization': 'Bearer $token'};
    Map<String, dynamic>? profile;
    try {
      profile = await api.get('/v1/patient/profile', asMap, headers: headers);
    } on AppError catch (e) {
      // 409 not_linked: akun belum terhubung ke data pasien → layar hubungkan/daftar.
      if (e.details['reason'] != 'not_linked') rethrow;
    }
    if (profile == null) {
      return PasienAccount(id: '', phone: _phone, consent: const PasienConsent(), nextStep: PasienNextStep.link);
    }
    final c = profile['consent'] is Map ? asMap(profile['consent']) : const <String, dynamic>{};
    final consent = PasienConsent(
      health: c['health_data'] as bool? ?? false,
      reminder: c['reminders'] as bool? ?? false,
      promo: c['promo'] as bool? ?? false,
      policyVersion: c['policy_version'] as String?,
    );
    final patient = V1.patient(profile);
    final phone = (patient.phone ?? _phone).replaceFirst('+', '');
    return PasienAccount(
      id: patient.id,
      phone: phone,
      patient: patient,
      consent: consent,
      // Data lama Laravel memakai persetujuan 'legacy': pasien tetap diminta menyetujui kebijakan baru.
      nextStep: consent.health && consent.policyVersion != 'legacy' ? PasienNextStep.ready : PasienNextStep.consent,
    );
  }

  Future<void> logout() => api.post('/v1/auth/logout', null, (_) {});

  Future<LinkCandidates> linkCandidates() async => _candidates;

  Future<PasienAccount> link({String? patientId, required DateTime birthDate}) async {
    await api.post('/v1/patient/link', {'candidate_id': patientId, 'birth_date': formatDay(birthDate)}, (_) {});
    return me();
  }

  /// Data diri pasien baru (akun belum terhubung ke data klinik).
  Future<PasienAccount> registerPatient(PatientDraft draft, {bool promo = false}) async {
    await api.post('/v1/patient/register', {
      ...V1.patientInput(draft),
      'consent': {
        'policy_version': V1.policyVersion.isEmpty ? 'app' : V1.policyVersion,
        'health_data': true,
        'reminders': true,
        'promo': promo,
      },
    }, (_) {});
    return me();
  }

  Future<PasienAccount> consent({required bool promo}) async {
    await api.post('/v1/patient/consent', {
      'policy_version': V1.policyVersion.isEmpty ? 'app' : V1.policyVersion,
      'health_data': true,
      'reminders': true,
      'promo': promo,
    }, (_) {});
    return me();
  }

  static SessionStatus _bookingStatus(String? s) => switch (s) {
    'accepted' => SessionStatus.scheduled,
    'cancelled' || 'rejected' || 'expired' => SessionStatus.cancelled,
    _ => SessionStatus.awaitingConfirmation,
  };

  /// Jadwal mendatang = booking; riwayat = sesi selesai versi pasien.
  Future<List<PasienSessionItem>> sessions({bool past = false}) async {
    if (past) {
      return api.get('/v1/patient/sessions', (d) => parseList(d, (m) => PasienSessionItem(
        id: m['session_id'].toString(),
        serviceName: m['service_name'] as String? ?? '',
        therapistName: m['therapist_name'] as String? ?? '',
        branchName: '',
        branchAddress: '',
        startAt: parseDate(m['date'])!,
        durationMin: 60,
        status: SessionStatus.done,
      )));
    }
    return api.get('/v1/patient/bookings', (d) => parseList(d, (m) {
      final start = parseDate(m['proposed_start']) ?? parseDate(m['requested_start'])!;
      return PasienSessionItem(
        id: m['id'].toString(),
        serviceName: (m['service'] is Map ? asMap(m['service'])['name'] : null) as String? ?? '',
        therapistName: '',
        branchName: '',
        branchAddress: '',
        startAt: start,
        durationMin: 60,
        status: _bookingStatus(m['status'] as String?),
        homeVisit: m['location_type'] == 'home_visit' ? const HomeVisit(address: '') : null,
      );
    }), query: {'scope': 'upcoming'});
  }

  Future<int> requestDeletionOtp() async {
    await api.post('/v1/auth/patient/otp', {'phone': _phone.isEmpty ? '0' : _phone, 'purpose': 'delete_account'}, (_) {});
    return 60;
  }

  Future<void> requestDeletion(String code) =>
      api.post('/v1/patient/account/deletion', {'otp_code': code}, (_) {});
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
