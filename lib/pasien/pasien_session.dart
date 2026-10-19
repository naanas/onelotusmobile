import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../data/api/api_client.dart';
import '../data/auth/auth_controller.dart';
import '../data/models/models.dart';
import '../data/pasien/pasien_api.dart';

/// Tahap masuk bagian pasien (§5.13): perkenalan → layar masuk bersama (nomor HP)
/// → kode OTP → hubungkan data lama / daftar → persetujuan data → siap.
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

  /// Tahap OTP dengan nomor terisi = kode sedang dikirim; kosong = belum
  /// mengisi nomor (pengguna berada di layar masuk bersama).
  bool get awaitingCode => phase == PasienPhase.otp && phone.isNotEmpty;

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
}

/// Klien API pasien: token pasien; 401 → sesi pasien berakhir (masuk lagi dengan OTP).
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

  static PasienPhase _phaseOf(PasienAccount a) => switch (a.nextStep) {
    PasienNextStep.link => PasienPhase.link,
    PasienNextStep.consent => PasienPhase.consent,
    PasienNextStep.ready => PasienPhase.ready,
  };

  Future<void> _restore() async {
    final store = ref.read(sessionStoreProvider);
    try {
      final onboarded = await store.read(PasienKeys.onboarded) == '1';
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

  /// Layar masuk mengenali nomor HP → kirim kode OTP WhatsApp. Melempar `AppError`.
  Future<int> requestOtp(String phone) async {
    final resendIn = await _api.requestOtp(phone);
    state = state.copyWith(phase: PasienPhase.otp, phone: phone);
    return resendIn;
  }

  Future<int> resendOtp() => _api.requestOtp(state.phone);

  /// Verifikasi kode → akun pasien; tahap berikut: hubungkan data / persetujuan / siap.
  Future<void> verify(String code) async {
    final (token, refresh, account) = await _api.verifyOtp(state.phone, code);
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

  /// "Ubah nomor" / kembali dari layar kode → layar masuk.
  void backToLogin() => state = const PasienSession(phase: PasienPhase.otp);

  Future<LinkCandidates> linkCandidates() => _api.linkCandidates();

  Future<void> link({String? patientId, required DateTime birthDate}) async =>
      _apply(await _api.link(patientId: patientId, birthDate: birthDate));

  Future<void> register(PatientDraft draft) async =>
      _apply(await _api.register(draft));

  Future<void> consent({required bool promo}) async =>
      _apply(await _api.consent(promo: promo));

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
    state = const PasienSession(phase: PasienPhase.otp);
  }
}
