import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tahap masuk bagian pasien (§5.13): perkenalan → layar masuk bersama (nomor HP)
/// → kode OTP → hubungkan data lama → persetujuan data → siap.
/// Slicing UI: disimpan di memori saja.
enum PasienPhase { onboarding, otp, link, consent, ready }

class PasienSession {
  const PasienSession({
    this.phase = PasienPhase.onboarding,
    this.phone = '',
    this.promoConsent = false,
  });

  final PasienPhase phase;
  final String phone;
  final bool promoConsent;

  /// Tahap OTP dengan nomor terisi = kode sedang dikirim; kosong = belum
  /// mengisi nomor (pengguna berada di layar masuk bersama).
  bool get awaitingCode => phase == PasienPhase.otp && phone.isNotEmpty;

  PasienSession copyWith({
    PasienPhase? phase,
    String? phone,
    bool? promoConsent,
  }) => PasienSession(
    phase: phase ?? this.phase,
    phone: phone ?? this.phone,
    promoConsent: promoConsent ?? this.promoConsent,
  );
}

final pasienSessionProvider =
    NotifierProvider<PasienSessionNotifier, PasienSession>(
      PasienSessionNotifier.new,
    );

class PasienSessionNotifier extends Notifier<PasienSession> {
  @override
  PasienSession build() => const PasienSession();

  void finishOnboarding() => state = state.copyWith(phase: PasienPhase.otp);

  /// Layar masuk mengenali nomor HP → kirim kode OTP ke nomor ini.
  void requestOtp(String phone) =>
      state = state.copyWith(phase: PasienPhase.otp, phone: phone);

  /// "Ubah nomor" / kembali dari layar kode → layar masuk.
  void backToLogin() => state = const PasienSession(phase: PasienPhase.otp);

  void verified() => state = state.copyWith(phase: PasienPhase.link);

  /// Data lama terhubung atau daftar baru — keduanya lanjut ke persetujuan.
  void linked() => state = state.copyWith(phase: PasienPhase.consent);

  void consented({required bool promo}) =>
      state = state.copyWith(phase: PasienPhase.ready, promoConsent: promo);

  void logout() => state = const PasienSession(phase: PasienPhase.otp);

  /// Lewati masuk (pengujian & pratinjau).
  void skipToReady() =>
      state = state.copyWith(phase: PasienPhase.ready, phone: '0812 3456 7890');
}
