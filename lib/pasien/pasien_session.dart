import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tahap masuk aplikasi pasien (§5.13): perkenalan → OTP → hubungkan data lama
/// → persetujuan data → siap. Slicing UI: disimpan di memori saja.
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

  void verified(String phone) =>
      state = state.copyWith(phase: PasienPhase.link, phone: phone);

  /// Data lama terhubung atau daftar baru — keduanya lanjut ke persetujuan.
  void linked() => state = state.copyWith(phase: PasienPhase.consent);

  void consented({required bool promo}) =>
      state = state.copyWith(phase: PasienPhase.ready, promoConsent: promo);

  void logout() => state = const PasienSession(phase: PasienPhase.otp);

  /// Lewati masuk (pengujian & pratinjau).
  void skipToReady() =>
      state = state.copyWith(phase: PasienPhase.ready, phone: '0812 3456 7890');
}
