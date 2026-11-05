import 'json.dart';
import 'patient.dart';

/// Isian data diri pasien (KS-04 kasir, daftar pasien baru di aplikasi pasien).
class PatientDraft {
  const PatientDraft({
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.phone,
    this.birthPlace,
    this.address,
    this.institution,
    this.hobby,
    this.heightCm,
    this.weightKg,
    this.initialComplaint,
    this.healthConsent = false,
  });

  final String name;
  final DateTime birthDate;
  final Gender gender;
  final String phone;
  final String? birthPlace;
  final String? address;
  final String? institution;
  final String? hobby;
  final int? heightCm;
  final int? weightKg;
  final String? initialComplaint;
  final bool healthConsent;

  Map<String, dynamic> toJson() => {
    'name': name,
    'birth_date': formatDay(birthDate),
    'gender': gender.api,
    'phone': phone,
    'birth_place': birthPlace,
    'address': address,
    'institution': institution,
    'hobby': hobby,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'initial_complaint': initialComplaint,
    'health_consent': healthConsent,
  };
}
