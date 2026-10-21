import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pasien/pasien_session.dart';
import '../api/api_client.dart';
import '../api/billing_api.dart';
import '../models/billing.dart';
import '../models/json.dart';

/// Booking pasien (PS-08/PS-10/PS-11).
class BookingV {
  const BookingV({
    required this.id,
    required this.status,
    required this.requestedStart,
    this.proposedStart,
    this.serviceName = '',
    this.homeVisit = false,
    this.note,
    this.sessionId,
    this.serviceId,
    this.branchId,
  });
  final String id, status, serviceName;
  final String? serviceId, branchId;
  final DateTime requestedStart;
  final DateTime? proposedStart;
  final bool homeVisit;
  final String? note, sessionId;

  DateTime get start => proposedStart ?? requestedStart;

  factory BookingV.fromJson(Map<String, dynamic> j) => BookingV(
    id: j['id'].toString(),
    status: j['status'] as String? ?? 'pending',
    requestedStart: parseDate(j['requested_start']) ?? DateTime.now(),
    proposedStart: parseDate(j['proposed_start']),
    serviceName: (j['service'] is Map ? asMap(j['service'])['name'] : null) as String? ?? '',
    homeVisit: j['location_type'] == 'home_visit',
    note: j['note'] as String?,
    sessionId: j['session_id']?.toString(),
    serviceId: (j['service'] is Map ? asMap(j['service'])['id'] : null)?.toString(),
    branchId: j['branch_id']?.toString(),
  );
}

const bookingStatusLabels = {
  'pending': 'Menunggu konfirmasi',
  'proposed': 'Klinik usul jam lain',
  'accepted': 'Terkonfirmasi',
  'rejected': 'Ditolak',
  'cancelled': 'Dibatalkan',
  'expired': 'Kedaluwarsa',
};

/// Alamat home visit tersimpan (PS-19).
class AddressV {
  const AddressV({required this.id, required this.label, required this.address, required this.lat, required this.lng, this.landmark, this.isDefault = false, this.inArea = true});
  final String id, label, address;
  final double lat, lng;
  final String? landmark;
  final bool isDefault, inArea;

  factory AddressV.fromJson(Map<String, dynamic> j) => AddressV(
    id: j['id'].toString(),
    label: j['label'] as String? ?? '',
    address: j['address'] as String? ?? '',
    lat: parseDouble(j['lat']) ?? 0,
    lng: parseDouble(j['lng']) ?? 0,
    landmark: j['landmark'] as String?,
    isDefault: j['is_default'] as bool? ?? false,
    inArea: j['in_service_area'] as bool? ?? true,
  );
}

/// Ringkasan sesi versi pasien (PS-12): tanpa catatan internal terapis.
class PatientSessionV {
  const PatientSessionV({required this.sessionId, required this.date, this.serviceName = '', this.therapistName = '', this.painBefore, this.painAfter, this.areas = const [], this.treatments = const [], this.conclusion, this.programId});
  final String sessionId, serviceName, therapistName;
  final DateTime date;
  final int? painBefore, painAfter;
  final List<String> areas, treatments;
  final String? conclusion, programId;

  factory PatientSessionV.fromJson(Map<String, dynamic> j) => PatientSessionV(
    sessionId: j['session_id'].toString(),
    date: parseDate(j['date']) ?? DateTime.now(),
    serviceName: j['service_name'] as String? ?? '',
    therapistName: j['therapist_name'] as String? ?? '',
    painBefore: parseInt(j['pain_before']),
    painAfter: parseInt(j['pain_after']),
    areas: [
      for (final a in (j['body_areas'] as List? ?? const []))
        if (a is Map) (a['area_code'] ?? a['code'] ?? '').toString() else a.toString(),
    ],
    treatments: parseStrings(j['treatments']),
    conclusion: j['conclusion'] as String?,
    programId: j['exercise_program_id']?.toString(),
  );
}

/// Slot jadwal kosong (GET /v1/slots).
typedef SlotV = ({DateTime start, DateTime end, bool available});

/// Endpoint aplikasi pasien selain masuk/akun: katalog, booking, bayar, paket, poin, latihan, alamat, notifikasi.
class PasienAppApi {
  PasienAppApi(this.api);
  final ApiClient api;

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── katalog & booking ──

  Future<List<({String id, String name, String address})>> branches() => api.get(
    '/v1/branches',
    (d) => parseList(d, (m) => (id: m['id'].toString(), name: m['name'] as String? ?? '', address: m['address'] as String? ?? '')),
  );

  Future<({List<ServiceV> services, List<PackageV> packages})> catalog({String? branchId}) => api.get('/v1/patient/catalog', (d) {
    final m = asMap(d);
    return (
      services: [for (final s in (m['services'] as List? ?? const [])) ServiceV.fromJson(asMap(s))],
      packages: [for (final p in (m['packages'] as List? ?? const [])) PackageV.fromJson(asMap(p))],
    );
  }, query: {'branch_id': branchId});

  Future<List<SlotV>> slots({required String branchId, required String serviceId, required DateTime date, bool homeVisit = false}) => api.get(
    '/v1/slots',
    (d) => parseList(d, (m) => (start: parseDate(m['start'])!, end: parseDate(m['end'])!, available: m['available'] as bool? ?? false)),
    query: {'branch_id': branchId, 'service_id': serviceId, 'date': _day(date), 'location_type': homeVisit ? 'home_visit' : 'clinic'},
  );

  Future<List<BookingV>> bookings({String scope = 'upcoming'}) =>
      api.get('/v1/patient/bookings', (d) => parseList(d, BookingV.fromJson), query: {'scope': scope});

  /// Booking baru → (booking, id tagihan DP bila klinik mewajibkan DP).
  Future<(BookingV, String?)> book(Map<String, dynamic> body) => api.post('/v1/patient/bookings', body, (d) {
    final m = asMap(d);
    final dp = m['dp_invoice'];
    return (BookingV.fromJson(asMap(m['booking'])), dp is Map ? dp['id']?.toString() : null);
  });

  Future<BookingV> reschedule(String id, DateTime start) =>
      api.post('/v1/patient/bookings/$id/reschedule', {'start': start.toUtc().toIso8601String()}, (d) => BookingV.fromJson(asMap(d)));

  Future<BookingV> cancelBooking(String id, String reason) =>
      api.post('/v1/patient/bookings/$id/cancel', {'reason': reason}, (d) => BookingV.fromJson(asMap(d)));

  // ── tagihan & bayar ──

  Future<List<InvoiceV>> invoices({String? status}) =>
      api.get('/v1/patient/invoices', (d) => parseList(d, InvoiceV.fromJson), query: {'status': status});

  Future<PaymentResult> pay(String invoiceId, {required String method, String? vaBank, String? ewallet, int? usePoints}) => api.post(
    '/v1/patient/invoices/$invoiceId/pay',
    {'method': method, 'va_bank': vaBank, 'ewallet': ewallet, 'use_points': usePoints},
    (d) => PaymentResult.fromJson(asMap(d)),
    headers: {'Idempotency-Key': BillingApi.key()},
  );

  Future<ReceiptV> receipt(String id) => api.get('/v1/receipts/$id', (d) => ReceiptV.fromJson(asMap(d)));

  Future<String?> receiptPdf(String id) => api.get('/v1/receipts/$id/pdf', (d) => asMap(d)['url'] as String?);

  // ── paket & poin ──

  Future<List<OwnershipV>> packages() => api.get('/v1/patient/packages', (d) => parseList(d, OwnershipV.fromJson));

  Future<InvoiceV> buyPackage(String packageId) =>
      api.post('/v1/patient/packages/purchase', {'package_id': packageId}, (d) => InvoiceV.fromJson(asMap(d)));

  Future<PointsSummaryV> points() => api.get('/v1/patient/points', (d) => PointsSummaryV.fromJson(asMap(d)));

  // ── latihan ──

  Future<List<ProgramV>> programs() => api.get('/v1/patient/exercises', (d) => parseList(d, ProgramV.fromJson));

  Future<void> logExercise(String itemId, {required bool done, String? note, DateTime? date}) => api.post(
    '/v1/patient/exercise-logs',
    {'program_item_id': itemId, 'date': _day(date ?? DateTime.now()), 'done': done, 'note': note},
    (_) {},
  );

  // ── riwayat sesi ──

  Future<List<PatientSessionV>> sessions() => api.get('/v1/patient/sessions', (d) => parseList(d, PatientSessionV.fromJson));

  // ── alamat ──

  Future<List<AddressV>> addresses() => api.get('/v1/patient/addresses', (d) => parseList(d, AddressV.fromJson));

  Future<AddressV> saveAddress(String? id, Map<String, dynamic> body) => id == null
      ? api.post('/v1/patient/addresses', body, (d) => AddressV.fromJson(asMap(d)))
      : api.patch('/v1/patient/addresses/$id', body, (d) => AddressV.fromJson(asMap(d)));

  Future<void> deleteAddress(String id) => api.delete('/v1/patient/addresses/$id', (_) {});

  // ── profil ──

  /// Lengkapi / ubah data diri (dipakai form booking untuk isian yang masih kosong).
  Future<void> updateProfile(Map<String, dynamic> body) => api.patch('/v1/patient/profile', body, (_) {});

  // ── notifikasi & preferensi ──

  Future<CursorPage<NotificationV>> notifications({String? cursor}) =>
      api.getPage('/v1/notifications', NotificationV.fromJson, query: {'cursor': cursor});

  Future<void> markAllRead() => api.post('/v1/notifications/read-all', null, (_) {});

  Future<({bool reminders, bool promo})> consent() => api.get('/v1/patient/consent', (d) {
    final m = asMap(d);
    return (reminders: m['reminders'] as bool? ?? true, promo: m['promo'] as bool? ?? false);
  });

  Future<void> saveConsent({required bool reminders, required bool promo, required String policyVersion}) => api.post(
    '/v1/patient/consent',
    {'policy_version': policyVersion, 'health_data': true, 'reminders': reminders, 'promo': promo},
    (_) {},
  );
}

final pasienAppApiProvider = Provider<PasienAppApi>((ref) => PasienAppApi(ref.watch(pasienApiProvider).api));
