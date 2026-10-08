import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tahap masuk bagian pasien (§5.13): perkenalan → OTP → hubungkan data lama
/// → persetujuan data → siap. Slicing UI: disimpan di memori saja.
enum PasienPhase { onboarding, otp, link, consent, ready }

class PasienSession {
  const PasienSession({
    this.phase = PasienPhase.onboarding,
    this.phone = '',
    this.promoConsent = false,
    this.staffMode = false,
  });

  final PasienPhase phase;
  final String phone;
  final bool promoConsent;

  /// Pengguna memilih "Staf klinik? Masuk di sini" (atau baru logout sebagai
  /// staf) — saat belum login, arahkan ke login staf, bukan perkenalan pasien.
  final bool staffMode;

  PasienSession copyWith({
    PasienPhase? phase,
    String? phone,
    bool? promoConsent,
    bool? staffMode,
  }) => PasienSession(
    phase: phase ?? this.phase,
    phone: phone ?? this.phone,
    promoConsent: promoConsent ?? this.promoConsent,
    staffMode: staffMode ?? this.staffMode,
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

  /// Dari layar pasien → login staf.
  void chooseStaff() => state = state.copyWith(staffMode: true);

  /// Dari login staf → masuk sebagai pasien (lewati perkenalan).
  void choosePatient() => state = state.copyWith(
    staffMode: false,
    phase: state.phase == PasienPhase.onboarding ? PasienPhase.otp : null,
  );

  /// Lewati masuk (pengujian & pratinjau).
  void skipToReady() =>
      state = state.copyWith(phase: PasienPhase.ready, phone: '0812 3456 7890');
}
