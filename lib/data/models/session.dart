import 'json.dart';
import 'status.dart';

/// Detail home visit (§5.4).
class HomeVisit {
  const HomeVisit({
    required this.address,
    this.landmark,
    this.distanceKm,
    this.lat,
    this.lng,
  });

  final String address;

  /// Patokan.
  final String? landmark;
  final double? distanceKm;
  final double? lat;
  final double? lng;

  factory HomeVisit.fromJson(Map<String, dynamic> j) => HomeVisit(
    address: j['address'] as String,
    landmark: j['landmark'] as String?,
    distanceKm: parseDouble(j['distance_km']),
    lat: parseDouble(j['lat']),
    lng: parseDouble(j['lng']),
  );

  Map<String, dynamic> toJson() => {
    'address': address,
    'landmark': landmark,
    'distance_km': distanceKm,
    'lat': lat,
    'lng': lng,
  };
}

/// Satu sesi di jadwal (SessionCard, §4). Nama pasien & layanan ikut disertakan
/// agar daftar jadwal bisa tampil tanpa request tambahan dan saat offline.
class Session {
  const Session({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientNumber,
    required this.therapistId,
    required this.therapistName,
    required this.serviceId,
    required this.serviceName,
    required this.branchId,
    required this.startAt,
    required this.durationMin,
    required this.status,
    this.room,
    this.homeVisit,
    this.isNewPatient = false,
    this.note,
    this.startedAt,
    this.endedAt,
    this.arrivedAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final int patientNumber;
  final String therapistId;
  final String therapistName;
  final String serviceId;
  final String serviceName;
  final String branchId;
  final DateTime startAt;
  final int durationMin;
  final SessionStatus status;
  final String? room;
  final HomeVisit? homeVisit;
  final bool isNewPatient;

  /// Catatan singkat di kartu, mis. "Cedera ringan · ankle kiri · sesi 4/5".
  final String? note;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isHomeVisit => homeVisit != null;

  /// Sudah selesai ditangani terapis (status pembayaran tidak relevan bagi terapis).
  bool get isFinished =>
      status == SessionStatus.done ||
      status == SessionStatus.unpaid ||
      status == SessionStatus.paid;

  /// Pasien belum hadir > 15 mnt dari jadwal (§6.3).
  bool isLateAt(DateTime now) =>
      status == SessionStatus.scheduled &&
      now.isAfter(startAt.add(const Duration(minutes: 15)));
  DateTime get endAt => startAt.add(Duration(minutes: durationMin));

  Session copyWith({
    SessionStatus? status,
    DateTime? arrivedAt,
    DateTime? startedAt,
    DateTime? endedAt,
  }) => Session(
    id: id,
    patientId: patientId,
    patientName: patientName,
    patientNumber: patientNumber,
    therapistId: therapistId,
    therapistName: therapistName,
    serviceId: serviceId,
    serviceName: serviceName,
    branchId: branchId,
    startAt: startAt,
    durationMin: durationMin,
    status: status ?? this.status,
    room: room,
    homeVisit: homeVisit,
    isNewPatient: isNewPatient,
    note: note,
    arrivedAt: arrivedAt ?? this.arrivedAt,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
  );

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    id: j['id'].toString(),
    patientId: j['patient_id'].toString(),
    patientName: j['patient_name'] as String,
    patientNumber: parseInt(j['patient_number']) ?? 0,
    therapistId: j['therapist_id'].toString(),
    therapistName: j['therapist_name'] as String,
    serviceId: j['service_id'].toString(),
    serviceName: j['service_name'] as String,
    branchId: j['branch_id'].toString(),
    startAt: parseDate(j['start_at'])!,
    durationMin: parseInt(j['duration_min']) ?? 60,
    status: SessionStatus.fromApi(j['status'] as String?),
    room: j['room'] as String?,
    homeVisit: j['home_visit'] == null
        ? null
        : HomeVisit.fromJson(j['home_visit'] as Map<String, dynamic>),
    isNewPatient: j['is_new_patient'] as bool? ?? false,
    note: j['note'] as String?,
    arrivedAt: parseDate(j['arrived_at']),
    startedAt: parseDate(j['started_at']),
    endedAt: parseDate(j['ended_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_id': patientId,
    'patient_name': patientName,
    'patient_number': patientNumber,
    'therapist_id': therapistId,
    'therapist_name': therapistName,
    'service_id': serviceId,
    'service_name': serviceName,
    'branch_id': branchId,
    'start_at': formatDate(startAt),
    'duration_min': durationMin,
    'status': status.api,
    'room': room,
    'home_visit': homeVisit?.toJson(),
    'is_new_patient': isNewPatient,
    'note': note,
    'arrived_at': formatDate(arrivedAt),
    'started_at': formatDate(startedAt),
    'ended_at': formatDate(endedAt),
  };
}
