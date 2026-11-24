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

/// Perkiraan biaya home visit (GET /v1/patient/home-visit/estimate): transport = km (dibulatkan ke atas) × tarif cabang.
class HomeVisitEstimateV {
  const HomeVisitEstimateV({
    required this.distanceKm,
    required this.transportFee,
    required this.ratePerKm,
    required this.servicePrice,
    required this.total,
    required this.inArea,
    this.maxKm,
  });
  final double distanceKm;
  final int transportFee, ratePerKm, servicePrice, total;
  final bool inArea;
  final double? maxKm;

  factory HomeVisitEstimateV.fromJson(Map<String, dynamic> j) => HomeVisitEstimateV(
    distanceKm: parseDouble(j['distance_km']) ?? 0,
    transportFee: parseInt(j['transport_fee']) ?? 0,
    ratePerKm: parseInt(j['rate_per_km']) ?? 0,
    servicePrice: parseInt(j['service_price']) ?? 0,
    total: parseInt(j['total']) ?? 0,
    inArea: j['in_area'] as bool? ?? true,
    maxKm: parseDouble(j['max_km']),
  );
}

/// Permintaan booking yang belum jadi sesi (GET /v1/patient/booking-requests): menunggu, diusulkan jam lain,
/// ditolak, atau kedaluwarsa. Yang sudah diterima tampil sebagai sesi di Jadwal saya.
class BookingRequestV {
  const BookingRequestV({
    required this.id,
    required this.status,
    required this.serviceName,
    required this.requestedStart,
    this.homeVisit = false,
    this.durationMin = 60,
    this.proposedStart,
    this.address,
    this.rejectReason,
    this.estimate,
  });
  final String id, status, serviceName;
  final bool homeVisit;
  final int durationMin;
  final DateTime requestedStart;
  final DateTime? proposedStart;
  final String? address, rejectReason;
  final HomeVisitEstimateV? estimate;

  factory BookingRequestV.fromJson(Map<String, dynamic> j) => BookingRequestV(
    id: j['id'].toString(),
    status: j['status'] as String? ?? 'pending',
    serviceName: j['service_name'] as String? ?? '',
    homeVisit: j['location_type'] == 'home_visit',
    durationMin: parseInt(j['duration_min']) ?? 60,
    requestedStart: parseDate(j['requested_start']) ?? DateTime.now(),
    proposedStart: parseDate(j['proposed_start']),
    address: (j['address'] as String?)?.trim().isEmpty ?? true ? null : j['address'] as String,
    rejectReason: j['reject_reason'] as String?,
    estimate: j['estimate'] is Map ? HomeVisitEstimateV.fromJson(asMap(j['estimate'])) : null,
  );
}

/// Saran alamat dari peta (GET /v1/geo/search, /v1/geo/reverse — data OpenStreetMap lewat backend).
class GeoPlaceV {
  const GeoPlaceV({required this.title, required this.subtitle, required this.address, required this.lat, required this.lng});
  final String title, subtitle, address;
  final double lat, lng;

  factory GeoPlaceV.fromJson(Map<String, dynamic> j) => GeoPlaceV(
    title: j['title'] as String? ?? '',
    subtitle: j['subtitle'] as String? ?? '',
    address: j['address'] as String? ?? '',
    lat: parseDouble(j['lat']) ?? 0,
    lng: parseDouble(j['lng']) ?? 0,
  );
}

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

/// Kanal bayar online + logo + biaya admin dari Dupay (GET /v1/patient/payment-channels).
class PayChannelV {
  const PayChannelV({
    required this.method,
    required this.code,
    required this.label,
    this.vaBank,
    this.ewallet,
    this.logo,
    this.fee = 0,
    this.total = 0,
    this.available = true,
  });

  /// qris | va | ewallet
  final String method, code, label;
  final String? vaBank, ewallet, logo;
  final int fee, total;
  final bool available;

  String get group => switch (method) {
    'va' => 'Virtual Account',
    'ewallet' => 'E-Wallet',
    _ => 'QRIS',
  };

  factory PayChannelV.fromJson(Map<String, dynamic> j) => PayChannelV(
    method: j['method'] as String? ?? 'qris',
    code: j['code']?.toString() ?? '',
    label: j['label'] as String? ?? '',
    vaBank: j['va_bank'] as String?,
    ewallet: j['ewallet'] as String?,
    logo: (j['logo'] as String?)?.trim().isEmpty ?? true ? null : (j['logo'] as String).trim(),
    fee: parseInt(j['fee']) ?? 0,
    total: parseInt(j['total']) ?? 0,
    available: j['available'] as bool? ?? true,
  );
}

/// Slot jadwal kosong (GET /v1/slots).
typedef SlotV = ({DateTime start, DateTime end, bool available});

/// Endpoint aplikasi pasien selain masuk/akun: katalog, booking, bayar, paket, poin, latihan, alamat, notifikasi.
class PasienAppApi {
  PasienAppApi(this.api);
  final ApiClient api;

  /// Hasil terakhir per endpoint (memori, satu sesi login — provider dibuat ulang saat ganti akun).
  /// Layar menampilkannya langsung, lalu memuat ulang di belakang (stale-while-revalidate).
  final _memo = <String, Object>{};

  /// Data terakhir dari [packages]/[invoices] (null bila belum pernah dimuat).
  T? cached<T>(String key) => _memo[key] as T?;

  Future<T> _remember<T extends Object>(String key, Future<T> f) => f.then((v) {
    _memo[key] = v;
    return v;
  });

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── katalog & booking ──

  Future<List<({String id, String name, String address})>> branches() => api.get(
    '/v1/branches',
    (d) => parseList(d, (m) => (id: m['id'].toString(), name: m['name'] as String? ?? '', address: m['address'] as String? ?? '')),
  );

  /// Titik lokasi cabang (pusat awal peta pilih titik bila posisi pasien belum diketahui).
  Future<List<({double lat, double lng})>> branchPoints() => api.get(
    '/v1/branches',
    (d) => [
      for (final m in (d as List? ?? const []))
        if (m is Map && (parseDouble(m['lat']) ?? 0) != 0)
          (lat: parseDouble(m['lat'])!, lng: parseDouble(m['lng']) ?? 0),
    ],
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

  /// Booking yang belum jadi sesi (menunggu / usulan jam lain / ditolak).
  Future<List<BookingRequestV>> bookingRequests() =>
      api.get('/v1/patient/booking-requests', (d) => parseList(d, BookingRequestV.fromJson));

  /// Setujui jam usulan klinik → langsung terkonfirmasi jadi sesi.
  Future<void> acceptProposal(String id) => api.post('/v1/patient/bookings/$id/accept-proposal', null, (_) {});

  /// Unggah satu foto rontgen (dienkripsi server sebelum disimpan) → id lampiran.
  Future<String> uploadIntake(List<int> bytes, String mime) =>
      api.putBytes('/v1/patient/intake-files', bytes, mime, (d) => asMap(d)['id'].toString());

  /// Kaitkan rontgen yang sudah diunggah ke booking (hanya unggahan akun ini sendiri).
  Future<void> attachIntake(String bookingId, List<String> ids) =>
      api.post('/v1/patient/bookings/$bookingId/intake-files', {'ids': ids}, (_) {});

  Future<HomeVisitEstimateV> homeVisitEstimate({
    required String branchId,
    required String serviceId,
    required String addressId,
  }) => api.get(
    '/v1/patient/home-visit/estimate',
    (d) => HomeVisitEstimateV.fromJson(asMap(d)),
    query: {'branch_id': branchId, 'service_id': serviceId, 'address_id': addressId},
  );

  Future<BookingV> reschedule(String id, DateTime start) =>
      api.post('/v1/patient/bookings/$id/reschedule', {'start': start.toUtc().toIso8601String()}, (d) => BookingV.fromJson(asMap(d)));

  Future<BookingV> cancelBooking(String id, String reason) =>
      api.post('/v1/patient/bookings/$id/cancel', {'reason': reason}, (d) => BookingV.fromJson(asMap(d)));

  // ── tagihan & bayar ──

  Future<List<InvoiceV>> invoices({String? status}) {
    final f = api.get('/v1/patient/invoices', (d) => parseList(d, InvoiceV.fromJson), query: {'status': status});
    return status == null ? _remember('invoices', f) : f;
  }

  Future<PaymentResult> pay(String invoiceId, {required String method, String? vaBank, String? ewallet, int? usePoints}) => api.post(
    '/v1/patient/invoices/$invoiceId/pay',
    {'method': method, 'va_bank': vaBank, 'ewallet': ewallet, 'use_points': usePoints},
    (d) => PaymentResult.fromJson(asMap(d)),
    headers: {'Idempotency-Key': BillingApi.key()},
  );

  /// Kanal bayar aktif + biaya admin untuk nominal [amount]; [code] = hanya satu kanal (hitung ulang biaya).
  Future<List<PayChannelV>> paymentChannels(int amount, {String? code}) => api.get(
    '/v1/patient/payment-channels',
    (d) => parseList(d, PayChannelV.fromJson),
    query: {'amount': '$amount', 'code': code},
  );

  Future<ReceiptV> receipt(String id) => api.get('/v1/receipts/$id', (d) => ReceiptV.fromJson(asMap(d)));

  Future<String?> receiptPdf(String id) => api.get('/v1/receipts/$id/pdf', (d) => asMap(d)['url'] as String?);

  // ── paket & poin ──

  Future<List<OwnershipV>> packages() =>
      _remember('packages', api.get('/v1/patient/packages', (d) => parseList(d, OwnershipV.fromJson)));

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

  /// Area tubuh yang ditandai terapis di satu sesi: `slug:sisi` (left/right/common) → mode (treated/calming).
  Future<Map<String, String>> sessionAreas(String id) => api.get('/v1/patient/sessions/$id', (d) {
    const side = {'l': 'left', 'r': 'right', 'c': 'common'};
    return {
      for (final a in (asMap(d)['body_areas'] as List? ?? const []))
        if (a is Map && a['area_code'] != null)
          '${a['area_code']}:${side[a['side']] ?? 'common'}': (a['mode'] ?? 'treated').toString(),
    };
  });

  // ── alamat ──

  Future<List<AddressV>> addresses() => api.get('/v1/patient/addresses', (d) => parseList(d, AddressV.fromJson));

  Future<AddressV> saveAddress(String? id, Map<String, dynamic> body) => id == null
      ? api.post('/v1/patient/addresses', body, (d) => AddressV.fromJson(asMap(d)))
      : api.patch('/v1/patient/addresses/$id', body, (d) => AddressV.fromJson(asMap(d)));

  Future<void> deleteAddress(String id) => api.delete('/v1/patient/addresses/$id', (_) {});

  /// Saran alamat saat mengetik; [lat]/[lng] = utamakan yang dekat posisi ini.
  Future<List<GeoPlaceV>> geoSearch(String q, {double? lat, double? lng}) => api.get(
    '/v1/geo/search',
    (d) => parseList(d, GeoPlaceV.fromJson),
    query: {'q': q, if (lat != null) 'lat': '$lat', if (lng != null) 'lng': '$lng'},
  );

  /// Alamat terdekat dari titik GPS (null bila tidak ditemukan).
  Future<GeoPlaceV?> geoReverse(double lat, double lng) => api.get(
    '/v1/geo/reverse',
    (d) => d is Map ? GeoPlaceV.fromJson(asMap(d)) : null,
    query: {'lat': '$lat', 'lng': '$lng'},
  );

  // ── profil ──

  /// Lengkapi / ubah data diri (dipakai form booking untuk isian yang masih kosong).
  Future<void> updateProfile(Map<String, dynamic> body) => api.patch('/v1/patient/profile', body, (_) {});

  // ── notifikasi & preferensi ──

  Future<CursorPage<NotificationV>> notifications({String? cursor}) =>
      api.getPage('/v1/notifications', NotificationV.fromJson, query: {'cursor': cursor});

  Future<void> markAllRead() => api.post('/v1/notifications/read-all', null, (_) {});

  /// Daftarkan token push FCM perangkat ini ke sesi login (server mengirim push ke token ini).
  Future<void> registerDevice(String token, {required String platform}) =>
      api.post('/v1/me/devices', {'push_token': token, 'platform': platform}, (_) {});

  /// Jumlah notifikasi belum dibaca untuk badge lonceng (maks. 50 dihitung; lebih dari itu → 50+).
  Future<int> unreadCount() => api
      .getPage('/v1/notifications', NotificationV.fromJson, query: {'unread_only': 'true', 'limit': '50'})
      .then((p) => p.items.length + (p.hasMore ? 1 : 0));

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

/// Badge lonceng Beranda. Dimuat ulang saat Beranda tampil lagi, aplikasi kembali dibuka, dan tiap menit.
final pasienUnreadProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(pasienAppApiProvider).unreadCount());
