import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/providers.dart';
import '../../data/models/models.dart' show NotificationV;
import 'klinik_cache.dart';
import 'klinik_models.dart';

final klinikApiProvider = Provider<KlinikApi>(
  (ref) => KlinikApi(ref.watch(apiClientProvider), ref.watch(klinikCacheProvider)),
);

Map<String, dynamic> _map(Object? d) => (d as Map).cast<String, dynamic>();
List<T> _list<T>(Object? d, T Function(Map<String, dynamic>) f) => [
  for (final x in (d as List? ?? const [])) f(_map(x)),
];

/// Satu halaman daftar (`{data, meta: {page, per_page, total}}`).
class KPage<T> {
  const KPage(this.items, this.total, this.page, this.perPage, [this.meta = const {}]);
  final List<T> items;
  final int total;
  final int page;
  final int perPage;
  final Map<String, dynamic> meta;
  bool get hasMore => page * perPage < total;
}

KPage<T> _page<T>(Object? body, T Function(Map<String, dynamic>) f, int page, int per) {
  final m = _map(body);
  final meta = _map(m['meta'] ?? const {});
  final items = _list(m['data'], f);
  // Backend lama (tanpa meta): semua data dalam satu halaman.
  if (m['meta'] == null) return KPage(items, items.length, 1, items.isEmpty ? per : items.length);
  return KPage(
    items,
    (meta['total'] as num?)?.toInt() ?? 0,
    (meta['page'] as num?)?.toInt() ?? page,
    (meta['per_page'] as num?)?.toInt() ?? per,
    meta,
  );
}

/// Isi `{data}` respons.
Object? _data(Object? body) => ApiClient.unwrap(body);

/// Menu staf versi Laravel: `/v1/klinik/*`. Semua gagal = AppError.
/// Bacaan lewat [KlinikCache] (tanpa request bila masih segar, 304 bila tidak berubah); perubahan mengosongkan cache.
class KlinikApi {
  KlinikApi(this._c, this.cache);
  final ApiClient _c;
  final KlinikCache cache;

  static const _p = '/v1/klinik';

  Future<T> _get<T>(String path, T Function(Object? body) parse, {Map<String, dynamic>? query}) =>
      cache.get(_c, path, parse, query: query);

  /// Setelah tambah/edit/hapus: semua daftar & detail dimuat ulang (revalidasi) saat dibuka lagi.
  Future<T> _changed<T>(Future<T> f) async {
    final r = await f;
    cache.expire();
    return r;
  }

  // ---- Data Pasien -----------------------------------------------------------

  Future<KPage<Pasien>> pasien({String cari = '', int page = 1, int perPage = 30}) => _get(
    '$_p/pasien',
    (b) => _page(b, Pasien.fromJson, page, perPage),
    query: {'cari': cari.trim().isEmpty ? null : cari.trim(), 'page': page, 'per_page': perPage},
  );

  Future<PasienDetail> detail(String id) => _get('$_p/pasien/$id', (b) {
    final m = _map(_data(b));
    return PasienDetail(
      Pasien.fromJson(_map(m['pasien'])),
      _list(m['pemeriksaan'], Pemeriksaan.fromJson),
    );
  });

  /// [body]: nomor (opsional), nama, ttl, tlp, alamat, gender, instansi, hobi, tb, bb, tempat_lahir.
  Future<Pasien> tambahPasien(Map<String, dynamic> body) =>
      _changed(_c.post('$_p/pasien', body, (d) => Pasien.fromJson(_map(d))));

  Future<Pasien> editPasien(String id, Map<String, dynamic> body) =>
      _changed(_c.put('$_p/pasien/$id', body, (d) => Pasien.fromJson(_map(d))));

  Future<void> hapusPasien(String id) => _changed(_c.delete('$_p/pasien/$id', (_) {}));

  // ---- Pemeriksaan -------------------------------------------------------------

  Future<Pemeriksaan> tambahPemeriksaan(String pasienId, PemeriksaanDraft d) => _changed(
    _c.post('$_p/pasien/$pasienId/pemeriksaan', d.toJson(), (x) => Pemeriksaan.fromJson(_map(x))),
  );

  Future<Pemeriksaan> pemeriksaan(int id) =>
      _get('$_p/pemeriksaan/$id', (b) => Pemeriksaan.fromJson(_map(_data(b))));

  Future<Pemeriksaan> editPemeriksaan(int id, PemeriksaanDraft d) =>
      _changed(_c.put('$_p/pemeriksaan/$id', d.toJson(), (x) => Pemeriksaan.fromJson(_map(x))));

  Future<void> hapusPemeriksaan(int id) => _changed(_c.delete('$_p/pemeriksaan/$id', (_) {}));

  /// Foto rontgen/MRI pasien (isi lewat `/v1/attachments/{id}/content`).
  Future<List<RontgenFile>> rontgen(String pasienId) =>
      _get('$_p/pasien/$pasienId/rontgen', (b) => _list(_data(b), RontgenFile.fromJson));

  /// Staf mengunggah satu foto rontgen/MRI (dienkripsi server; maks. 8 MB).
  Future<RontgenFile> unggahRontgen(
    String pasienId,
    List<int> bytes,
    String mime, {
    void Function(double progress)? onProgress,
  }) => _changed(
    _c.putBytes(
      '$_p/pasien/$pasienId/rontgen',
      bytes,
      mime,
      (d) => RontgenFile.fromJson(_map(d)),
      onProgress: onProgress,
    ),
  );

  /// Hanya foto yang diunggah staf.
  Future<void> hapusRontgen(String pasienId, String fileId) =>
      _changed(_c.delete('$_p/pasien/$pasienId/rontgen/$fileId', (_) {}));

  Future<Uint8List> isiFile(String fileId) => _c.getBytes('/v1/attachments/$fileId/content');

  Future<List<RontgenFile>> rontgenBooking(String bookingId) => _get(
    '/v1/bookings/$bookingId/attachments',
    (b) => _list(_data(b), (j) => RontgenFile(id: j['id'].toString(), mime: j['mime'] as String? ?? '')),
  );

  // ---- Rekap & Export ------------------------------------------------------------

  /// meta: total (pemeriksaan) & total_pasien bulan itu.
  Future<KPage<RekapRow>> rekap(DateTime bulan, {int page = 1, int perPage = 30}) => _get(
    '$_p/rekap',
    (b) => _page(b, RekapRow.fromJson, page, perPage),
    query: {'bulan': ym(bulan), 'page': page, 'per_page': perPage},
  );

  /// File .xlsx (Laravel PasienExport). Bulan tanpa data → AppError notFound.
  Future<Uint8List> export(DateTime bulan) => _c.getBytes('$_p/export?bulan=${ym(bulan)}');

  // ---- Formulir --------------------------------------------------------------------

  Future<KPage<Formulir>> formulir({int page = 1, int perPage = 20}) => _get(
    '$_p/formulir',
    (b) => _page(b, Formulir.fromJson, page, perPage),
    query: {'page': page, 'per_page': perPage},
  );

  /// Jumlah kiriman yang menunggu (badge).
  Future<int> formulirCount() => formulir(perPage: 1).then((p) => p.total);

  Future<Formulir> formulirDetail(String id) =>
      _get('$_p/formulir/$id', (b) => Formulir.fromJson(_map(_data(b))));

  /// Setujui kiriman → pasien mendapat nomor (bila belum) + isian awal pemeriksaan.
  Future<({Pasien pasien, Intake intake})> setujui(String id, {int? nomor}) =>
      _changed(_c.post('$_p/formulir/$id/setujui', {'nomor': ?nomor}, (d) {
        final m = _map(d);
        return (
          pasien: Pasien.fromJson(_map(m['pasien'])),
          intake: Intake.fromJson((m['intake'] as Map?)?.cast<String, dynamic>()),
        );
      }));

  Future<void> tolak(String id, String alasan) =>
      _changed(_c.post('$_p/formulir/$id/tolak', {'alasan': alasan}, (_) {}));

  // ---- Notifikasi (lonceng) ----------------------------------------------------------

  Future<CursorPage<NotificationV>> notifikasi({String? cursor}) =>
      _c.getPage('/v1/notifications', NotificationV.fromJson, query: {'cursor': cursor});

  /// Jumlah belum dibaca (maks. 50 dihitung; lebih → 51 = "50+").
  Future<int> belumDibaca() => _c
      .getPage('/v1/notifications', NotificationV.fromJson, query: {'unread_only': 'true', 'limit': '50'})
      .then((p) => p.items.length + (p.hasMore ? 1 : 0));

  Future<void> bacaSemua() => _c.post('/v1/notifications/read-all', null, (_) {});

  /// Token push FCM perangkat ini (server mengirim push "pasien baru booking" ke token ini).
  Future<void> daftarPerangkat(String token, {required String platform}) =>
      _c.post('/v1/me/devices', {'push_token': token, 'platform': platform}, (_) {});

  // ---- User Management (admin) ------------------------------------------------------

  Future<List<KUser>> users() => _get('$_p/users', (b) => _list(_data(b), KUser.fromJson));

  Future<KUser> tambahUser({
    required String name,
    required String username,
    required String password,
    required bool admin,
  }) => _changed(
    _c.post('$_p/users', {
      'name': name,
      'username': username,
      'password': password,
      'role': admin ? 'admin' : 'terapis',
    }, (d) => KUser.fromJson(_map(d))),
  );

  Future<void> hapusUser(String id) => _changed(_c.delete('$_p/users/$id', (_) {}));

  Future<void> ubahPassword(String id, String password) =>
      _c.put('$_p/users/$id/password', {'password': password}, (_) {});
}
