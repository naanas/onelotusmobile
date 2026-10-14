import 'json.dart';
import 'patient.dart';
import 'session.dart';
import 'status.dart';

/// Tahap berikut akun pasien dari server (`next_step`), sama dengan `PasienPhase`.
enum PasienNextStep {
  link('link'),
  consent('consent'),
  ready('ready');

  const PasienNextStep(this.api);
  final String api;

  static PasienNextStep fromApi(Object? v) =>
      values.where((s) => s.api == v).firstOrNull ?? PasienNextStep.link;
}

class PasienConsent {
  const PasienConsent({
    this.health = false,
    this.reminder = false,
    this.promo = false,
    this.policyVersion,
  });

  final bool health;
  final bool reminder;
  final bool promo;
  final String? policyVersion;

  factory PasienConsent.fromJson(Map<String, dynamic> j) => PasienConsent(
    health: j['health'] as bool? ?? false,
    reminder: j['reminder'] as bool? ?? false,
    promo: j['promo'] as bool? ?? false,
    policyVersion: j['policy_version'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'health': health,
    'reminder': reminder,
    'promo': promo,
    'policy_version': policyVersion,
  };
}

/// Akun pasien di aplikasi (`/v1/pasien/me`).
class PasienAccount {
  const PasienAccount({
    required this.id,
    required this.phone,
    required this.consent,
    required this.nextStep,
    this.patient,
  });

  final String id;

  /// Format `62xxxxxxxxx`.
  final String phone;
  final Patient? patient;
  final PasienConsent consent;
  final PasienNextStep nextStep;

  /// Nomor untuk ditampilkan: `0812 3456 7890`.
  String get phoneDisplay {
    final local = phone.startsWith('62') ? '0${phone.substring(2)}' : phone;
    final b = StringBuffer();
    for (var i = 0; i < local.length; i++) {
      if (i == 4 || i == 8) b.write(' ');
      b.write(local[i]);
    }
    return b.toString();
  }

  factory PasienAccount.fromJson(Map<String, dynamic> j) => PasienAccount(
    id: j['id'].toString(),
    phone: j['phone'] as String? ?? '',
    patient: j['patient'] == null
        ? null
        : Patient.fromJson((j['patient'] as Map).cast<String, dynamic>()),
    consent: PasienConsent.fromJson(
      ((j['consent'] as Map?) ?? const {}).cast<String, dynamic>(),
    ),
    nextStep: PasienNextStep.fromApi(j['next_step']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'patient': patient?.toJson(),
    'consent': consent.toJson(),
    'next_step': nextStep.api,
  };
}

/// Pasien lama dengan HP sama (PS-03); nama tersamar.
class LinkCandidate {
  const LinkCandidate({required this.id, required this.maskedName});
  final String id;
  final String maskedName;
}

class LinkCandidates {
  const LinkCandidates({
    required this.candidates,
    required this.locked,
    required this.attemptsLeft,
  });

  final List<LinkCandidate> candidates;
  final bool locked;
  final int attemptsLeft;

  factory LinkCandidates.fromJson(Map<String, dynamic> j) => LinkCandidates(
    candidates: [
      for (final c in (j['candidates'] as List? ?? const []))
        LinkCandidate(
          id: (c as Map)['id'].toString(),
          maskedName: c['masked_name'] as String,
        ),
    ],
    locked: j['locked'] as bool? ?? false,
    attemptsLeft: parseInt(j['attempts_left']) ?? 0,
  );
}

/// Jadwal versi pasien (PS-10): tanpa catatan internal.
class PasienSessionItem {
  const PasienSessionItem({
    required this.id,
    required this.serviceName,
    required this.therapistName,
    required this.branchName,
    required this.branchAddress,
    required this.startAt,
    required this.durationMin,
    required this.status,
    this.homeVisit,
  });

  final String id;
  final String serviceName;
  final String therapistName;
  final String branchName;
  final String branchAddress;
  final DateTime startAt;
  final int durationMin;
  final SessionStatus status;
  final HomeVisit? homeVisit;

  factory PasienSessionItem.fromJson(Map<String, dynamic> j) =>
      PasienSessionItem(
        id: j['id'].toString(),
        serviceName: j['service_name'] as String,
        therapistName: j['therapist_name'] as String,
        branchName: j['branch_name'] as String? ?? '',
        branchAddress: j['branch_address'] as String? ?? '',
        startAt: parseDate(j['start_at'])!,
        durationMin: parseInt(j['duration_min']) ?? 60,
        status: SessionStatus.fromApi(j['status'] as String?),
        homeVisit: j['home_visit'] == null
            ? null
            : HomeVisit.fromJson(
                (j['home_visit'] as Map).cast<String, dynamic>(),
              ),
      );
}
