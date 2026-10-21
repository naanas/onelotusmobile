import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../data/api/api_client.dart';
import '../data/auth/auth_controller.dart';
import '../data/models/models.dart';
import '../data/pasien/pasien_api.dart';

/// Tahap masuk bagian pasien (§5.13): perkenalan → layar masuk bersama (nomor HP + password;
/// daftar = OTP WhatsApp + buat password) → persetujuan data → hubungkan data lama / isi data diri → siap.
/// `otp` = belum masuk (nama dipertahankan agar sesi tersimpan lama tetap terbaca).
/// `restoring` = sesi tersimpan sedang dipulihkan saat aplikasi dibuka.
enum PasienPhase { restoring, onboarding, otp, link, consent, ready }

class PasienSession {
  const PasienSession({
    this.phase = PasienPhase.onboarding,
    this.phone = '',
    this.account,
  });

  final PasienPhase phase;

  /// Nomor yang sedang diverifikasi (format tampilan pengguna).
  final String phone;
  final PasienAccount? account;

  bool get promoConsent => account?.consent.promo ?? false;

  PasienSession copyWith({
    PasienPhase? phase,
    String? phone,
    PasienAccount? account,
  }) => PasienSession(
    phase: phase ?? this.phase,
    phone: phone ?? this.phone,
    account: account ?? this.account,
  );
}

/// Kunci penyimpanan aman bagian pasien.
abstract final class PasienKeys {
  static const token = 'pasien.token';
  static const refresh = 'pasien.refresh';
  static const account = 'pasien.account';
  static const onboarded = 'pasien.onboarded';

  /// Persetujuan yang diberikan sebelum akun terhubung ke data pasien ('promo' / 'nopromo').
  static const consentDraft = 'pasien.consent_draft';
}

/// Klien API pasien: token pasien; 401 → sesi pasien berakhir (masuk lagi).
final pasienApiProvider = Provider<PasienApi>(
  (ref) => PasienApi(
    ApiClient(
      baseUrl: AppConfig.apiUrl,
      token: () => ref.read(pasienTokenProvider),
      onUnauthorized: () => ref.read(pasienSessionProvider.notifier).expire(),
      refresh: () => ref.read(pasienSessionProvider.notifier).refreshTokens(),
      deviceId: () => ref.read(authProvider.notifier).deviceIdSync,
    ),
    deviceId: () => ref.read(authProvider.notifier).deviceId(),
  ),
);

final pasienSessionProvider =
    NotifierProvider<PasienSessionNotifier, PasienSession>(
      PasienSessionNotifier.new,
    );

class PasienSessionNotifier extends Notifier<PasienSession> {
  PasienApi get _api => ref.read(pasienApiProvider);

  @override
  PasienSession build() {
    Future.microtask(_restore);
    return const PasienSession(phase: PasienPhase.restoring);
  }

  /// Persetujuan yang sudah diberikan tapi belum terkirim (akun belum terhubung ke data pasien).
  /// null = belum setuju; true/false = setuju, dengan/tanpa info promo.
  bool? _consentPromo;

  /// Urutan: buat password → persetujuan → hubungkan data / isi data diri → siap.
  PasienPhase _phaseOf(PasienAccount a) => switch (a.nextStep) {
    PasienNextStep.link =>
      _consentPromo == null ? PasienPhase.consent : PasienPhase.link,
    PasienNextStep.consent => PasienPhase.consent,
    PasienNextStep.ready => PasienPhase.ready,
  };

  Future<void> _restore() async {
    final store = ref.read(sessionStoreProvider);
    try {
      final onboarded = await store.read(PasienKeys.onboarded) == '1';
      final draft = await store.read(PasienKeys.consentDraft);
      _consentPromo = draft == null ? null : draft == 'promo';
      final token = await store.read(PasienKeys.token);
      final cached = await store.read(PasienKeys.account);
      if (token == null || cached == null) {
        state = PasienSession(
          phase: onboarded ? PasienPhase.otp : PasienPhase.onboarding,
        );
        return;
      }
      ref.read(pasienTokenProvider.notifier).set(token);
      final account = PasienAccount.fromJson(
        (jsonDecode(cached) as Map).cast<String, dynamic>(),
      );
      state = PasienSession(phase: _phaseOf(account), account: account);
      // Perbarui dari server di belakang layar (offline → pakai data tersimpan).
      unawaited(refresh());
    } catch (_) {
      state = const PasienSession(phase: PasienPhase.onboarding);
    }
  }

  Future<void> _save(String? token, PasienAccount? account) async {
    final store = ref.read(sessionStoreProvider);
    if (token != null) await store.write(PasienKeys.token, token);
    if (account != null) {
      await store.write(PasienKeys.account, jsonEncode(account.toJson()));
    }
  }

  void _apply(PasienAccount account) {
    state = PasienSession(phase: _phaseOf(account), account: account);
    unawaited(_save(null, account));
  }

  Future<void> finishOnboarding() async {
    state = const PasienSession(phase: PasienPhase.otp);
    await ref.read(sessionStoreProvider).write(PasienKeys.onboarded, '1');
  }

  /// Masuk dengan nomor HP + password. Melempar `AppError`.
  Future<void> login(String phone, String password) async =>
      _start(await _api.login(phone, password));

  /// Kirim kode OTP WhatsApp untuk daftar (`register`) atau lupa password (`reset_password`).
  Future<int> requestOtp(String phone, String purpose) =>
      _api.requestOtp(phone, purpose: purpose);

  /// Cek kode OTP lebih dulu → token verifikasi untuk langkah buat password.
  Future<String> verifyCode(String phone, String purpose, String code) =>
      _api.verifyCode(phone, purpose, code);

  /// Daftar akun: token verifikasi + password → masuk; tahap berikut: hubungkan data / persetujuan / siap.
  Future<void> register(
    String phone,
    String verification,
    String password,
  ) async => _start(await _api.register(phone, verification, password));

  /// Lupa password: token verifikasi + password baru (belum masuk; lanjut masuk dengan password baru).
  Future<void> resetPassword(
    String phone,
    String verification,
    String password,
  ) => _api.resetPassword(phone, verification, password);

  Future<void> _start((String, String, PasienAccount) r) async {
    final (token, refresh, account) = r;
    ref.read(pasienTokenProvider.notifier).set(token);
    await ref.read(sessionStoreProvider).write(PasienKeys.refresh, refresh);
    await _save(token, account);
    _apply(account);
  }

  /// Access token pasien kedaluwarsa (15 menit) → tukar refresh token.
  Future<bool> refreshTokens() async {
    final store = ref.read(sessionStoreProvider);
    final rt = await store.read(PasienKeys.refresh);
    if (rt == null) return false;
    final pair = await _api.refresh(rt);
    if (pair == null) return false;
    ref.read(pasienTokenProvider.notifier).set(pair.$1);
    await store.write(PasienKeys.token, pair.$1);
    await store.write(PasienKeys.refresh, pair.$2);
    return true;
  }

  Future<LinkCandidates> linkCandidates() => _api.linkCandidates();

  /// Hubungkan ke data lama → kirim persetujuan yang sudah diberikan sesudah buat password.
  Future<void> link({String? patientId, required DateTime birthDate}) async {
    await _api.link(patientId: patientId, birthDate: birthDate);
    await _flushConsent();
  }

  /// Data diri pasien baru (persetujuan ikut terkirim bersama data diri).
  Future<void> registerPatient(PatientDraft draft) async {
    final account = await _api.registerPatient(
      draft,
      promo: _consentPromo ?? false,
    );
    await _clearConsentDraft();
    _apply(account);
  }

  /// Layar Persetujuan: akun sudah terhubung → kirim langsung; belum → simpan dulu, lanjut hubungkan data.
  Future<void> consent({required bool promo}) async {
    final account = state.account;
    if (account?.patient != null) {
      _apply(await _api.consent(promo: promo));
      await _clearConsentDraft();
      return;
    }
    _consentPromo = promo;
    await ref
        .read(sessionStoreProvider)
        .write(PasienKeys.consentDraft, promo ? 'promo' : 'nopromo');
    if (account != null) _apply(account);
  }

  Future<void> _flushConsent() async {
    final promo = _consentPromo;
    _apply(promo == null ? await _api.me() : await _api.consent(promo: promo));
    await _clearConsentDraft();
  }

  Future<void> _clearConsentDraft() async {
    _consentPromo = null;
    await ref.read(sessionStoreProvider).delete(PasienKeys.consentDraft);
  }

  Future<void> refresh() async {
    try {
      _apply(await _api.me());
    } catch (_) {
      // Offline / server bermasalah: tetap pakai akun tersimpan.
    }
  }

  /// Keluar: cabut token di server (bila bisa), hapus sesi di HP.
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    await _clear();
  }

  /// Pratinjau & render layar di tes: anggap pasien sudah masuk dengan [account].
  @visibleForTesting
  void debugSetReady(PasienAccount account) =>
      state = PasienSession(phase: PasienPhase.ready, account: account);

  /// Token ditolak server (401) atau akun dihapus.
  Future<void> expire() => _clear();

  Future<void> _clear() async {
    final store = ref.read(sessionStoreProvider);
    ref.read(pasienTokenProvider.notifier).set(null);
    await store.delete(PasienKeys.token);
    await store.delete(PasienKeys.refresh);
    await store.delete(PasienKeys.account);
    await store.delete(PasienKeys.consentDraft);
    _consentPromo = null;
    state = const PasienSession(phase: PasienPhase.otp);
  }
}
