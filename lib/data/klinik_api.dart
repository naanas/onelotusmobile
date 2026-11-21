import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth.dart';
import 'models.dart';

final klinikApiProvider = Provider<KlinikApi>(
  (ref) => KlinikApi(ref.watch(apiClientProvider)),
);

Map<String, dynamic> _map(Object? d) => (d as Map).cast<String, dynamic>();
List<T> _list<T>(Object? d, T Function(Map<String, dynamic>) f) => [
  for (final x in (d as List? ?? const [])) f(_map(x)),
];

/// Endpoint One Lotus API (backend Go, alur Laravel). Semua gagal = [AppError].
class KlinikApi {
  KlinikApi(this._c);
  final ApiClient _c;

  // ---- Data Pasien -----------------------------------------------------------

  Future<PasienPage> pasien({
    String cari = '',
    int page = 1,
    int perPage = 30,
  }) => _c.getBody(
    '/v1/pasien',
    (body) {
      final m = _map(body);
      final meta = _map(m['meta'] ?? const {});
      return PasienPage(
        _list(m['data'], Pasien.fromJson),
        (meta['total'] as num?)?.toInt() ?? 0,
        (meta['page'] as num?)?.toInt() ?? page,
        (meta['per_page'] as num?)?.toInt() ?? perPage,
      );
    },
    query: {
      'cari': cari.trim().isEmpty ? null : cari.trim(),
      'page': page,
      'per_page': perPage,
    },
  );

  Future<PasienDetail> detail(int id) => _c.get('/v1/pasien/$id', (d) {
    final m = _map(d);
    return PasienDetail(
      Pasien.fromJson(_map(m['pasien'])),
      _list(m['perawatan'], Perawatan.fromJson),
    );
  });

  /// Tambah pasien. [body]: nomor (opsional), nama, ttl, tlp, alamat, gender, instansi, hobi, tb, bb.
  Future<Pasien> tambahPasien(Map<String, dynamic> body) =>
      _c.post('/v1/pasien', body, (d) => Pasien.fromJson(_map(d)));

  Future<Pasien> editPasien(int id, Map<String, dynamic> body) =>
      _c.put('/v1/pasien/$id', body, (d) => Pasien.fromJson(_map(d)));

  Future<void> hapusPasien(int id) => _c.delete('/v1/pasien/$id', (_) {});

  // ---- Pemeriksaan -------------------------------------------------------------

  Future<Perawatan> tambahPerawatan(int pasienId, PerawatanDraft d) => _c.post(
    '/v1/pasien/$pasienId/perawatan',
    d.toJson(),
    (x) => Perawatan.fromJson(_map(x)),
  );

  Future<Perawatan> perawatan(int id) =>
      _c.get('/v1/perawatan/$id', (x) => Perawatan.fromJson(_map(x)));

  Future<Perawatan> editPerawatan(int id, PerawatanDraft d) => _c.put(
    '/v1/perawatan/$id',
    d.toJson(),
    (x) => Perawatan.fromJson(_map(x)),
  );

  Future<void> hapusPerawatan(int id) => _c.delete('/v1/perawatan/$id', (_) {});

  // ---- Rekap & Export ------------------------------------------------------------

  Future<List<RekapRow>> rekap(DateTime bulan) => _c.get(
    '/v1/rekap',
    (d) => _list(d, RekapRow.fromJson),
    query: {'bulan': ym(bulan)},
  );

  /// File .xlsx (Laravel PasienExport). Bulan tanpa data → AppError notFound.
  Future<Uint8List> export(DateTime bulan) =>
      _c.getBytes('/v1/export?bulan=${ym(bulan)}');

  // ---- Formulir --------------------------------------------------------------------

  Future<List<Formulir>> formulir() =>
      _c.get('/v1/formulir', (d) => _list(d, Formulir.fromJson));

  /// Tambah Pasien dari formulir → id pasien baru + isian awal pemeriksaan.
  Future<({int pasienId, PerawatanDraft prefill})> tambahDariFormulir(int id) =>
      _c.post('/v1/formulir/$id/tambah-pasien', null, (d) {
        final m = _map(d);
        return (
          pasienId: (m['pasien_id'] as num).toInt(),
          prefill: PerawatanDraft(
            keluhan: m['keluhan'] as String?,
            penyebab: m['penyebab'] as String?,
            lamaCedera: m['lama'] as String?,
            hasilRontgen: m['rontgen'] as String?,
          ),
        );
      });

  // ---- User Management (admin) ------------------------------------------------------

  Future<List<AppUser>> users() =>
      _c.get('/v1/users', (d) => _list(d, AppUser.fromJson));

  Future<AppUser> tambahUser({
    required String name,
    required String username,
    required String password,
  }) => _c.post('/v1/users', {
    'name': name,
    'username': username,
    'password': password,
  }, (d) => AppUser.fromJson(_map(d)));

  Future<void> hapusUser(int id) => _c.delete('/v1/users/$id', (_) {});

  Future<void> ubahPassword(int id, String password) =>
      _c.put('/v1/users/$id/password', {'password': password}, (_) {});
}
