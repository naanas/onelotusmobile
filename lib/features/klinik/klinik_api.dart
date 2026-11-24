import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/providers.dart';
import 'klinik_models.dart';

final klinikApiProvider = Provider<KlinikApi>(
  (ref) => KlinikApi(ref.watch(apiClientProvider)),
);

Map<String, dynamic> _map(Object? d) => (d as Map).cast<String, dynamic>();
List<T> _list<T>(Object? d, T Function(Map<String, dynamic>) f) => [
  for (final x in (d as List? ?? const [])) f(_map(x)),
];

/// Menu staf versi Laravel: `/v1/klinik/*`. Semua gagal = AppError.
class KlinikApi {
  KlinikApi(this._c);
  final ApiClient _c;

  static const _p = '/v1/klinik';

  // ---- Data Pasien -----------------------------------------------------------

  Future<PasienPage> pasien({String cari = '', int page = 1, int perPage = 30}) =>
      _c.getBody(
        '$_p/pasien',
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

  Future<PasienDetail> detail(String id) => _c.get('$_p/pasien/$id', (d) {
    final m = _map(d);
    return PasienDetail(
      Pasien.fromJson(_map(m['pasien'])),
      _list(m['pemeriksaan'], Pemeriksaan.fromJson),
    );
  });

  /// [body]: nomor (opsional), nama, ttl, tlp, alamat, gender, instansi, hobi, tb, bb, tempat_lahir.
  Future<Pasien> tambahPasien(Map<String, dynamic> body) =>
      _c.post('$_p/pasien', body, (d) => Pasien.fromJson(_map(d)));

  Future<Pasien> editPasien(String id, Map<String, dynamic> body) =>
      _c.put('$_p/pasien/$id', body, (d) => Pasien.fromJson(_map(d)));

  Future<void> hapusPasien(String id) => _c.delete('$_p/pasien/$id', (_) {});

  // ---- Pemeriksaan -------------------------------------------------------------

  Future<Pemeriksaan> tambahPemeriksaan(String pasienId, PemeriksaanDraft d) =>
      _c.post(
        '$_p/pasien/$pasienId/pemeriksaan',
        d.toJson(),
        (x) => Pemeriksaan.fromJson(_map(x)),
      );

  Future<Pemeriksaan> pemeriksaan(int id) =>
      _c.get('$_p/pemeriksaan/$id', (x) => Pemeriksaan.fromJson(_map(x)));

  Future<Pemeriksaan> editPemeriksaan(int id, PemeriksaanDraft d) => _c.put(
    '$_p/pemeriksaan/$id',
    d.toJson(),
    (x) => Pemeriksaan.fromJson(_map(x)),
  );

  Future<void> hapusPemeriksaan(int id) =>
      _c.delete('$_p/pemeriksaan/$id', (_) {});

  /// Foto rontgen/MRI yang diunggah pasien (isi lewat `/v1/attachments/{id}/content`).
  Future<List<RontgenFile>> rontgen(String pasienId) =>
      _c.get('$_p/pasien/$pasienId/rontgen', (d) => _list(d, RontgenFile.fromJson));

  /// Staf mengunggah satu foto rontgen/MRI (dienkripsi server; maks. 8 MB).
  Future<RontgenFile> unggahRontgen(String pasienId, List<int> bytes, String mime) =>
      _c.putBytes('$_p/pasien/$pasienId/rontgen', bytes, mime, (d) => RontgenFile.fromJson(_map(d)));

  /// Hanya foto yang diunggah staf.
  Future<void> hapusRontgen(String pasienId, String fileId) =>
      _c.delete('$_p/pasien/$pasienId/rontgen/$fileId', (_) {});

  Future<Uint8List> isiFile(String fileId) => _c.getBytes('/v1/attachments/$fileId/content');

  Future<List<RontgenFile>> rontgenBooking(String bookingId) => _c.get(
    '/v1/bookings/$bookingId/attachments',
    (d) => _list(d, (j) => RontgenFile(id: j['id'].toString(), mime: j['mime'] as String? ?? '')),
  );

  // ---- Rekap & Export ------------------------------------------------------------

  Future<List<RekapRow>> rekap(DateTime bulan) => _c.get(
    '$_p/rekap',
    (d) => _list(d, RekapRow.fromJson),
    query: {'bulan': ym(bulan)},
  );

  /// File .xlsx (Laravel PasienExport). Bulan tanpa data → AppError notFound.
  Future<Uint8List> export(DateTime bulan) =>
      _c.getBytes('$_p/export?bulan=${ym(bulan)}');

  // ---- Formulir --------------------------------------------------------------------

  Future<List<Formulir>> formulir() =>
      _c.get('$_p/formulir', (d) => _list(d, Formulir.fromJson));

  /// Setujui kiriman → pasien mendapat nomor (bila belum) + isian awal pemeriksaan.
  Future<({Pasien pasien, Intake intake})> setujui(String id, {int? nomor}) =>
      _c.post('$_p/formulir/$id/setujui', {'nomor': ?nomor}, (d) {
        final m = _map(d);
        return (
          pasien: Pasien.fromJson(_map(m['pasien'])),
          intake: Intake.fromJson((m['intake'] as Map?)?.cast<String, dynamic>()),
        );
      });

  Future<void> tolak(String id, String alasan) =>
      _c.post('$_p/formulir/$id/tolak', {'alasan': alasan}, (_) {});

  // ---- User Management (admin) ------------------------------------------------------

  Future<List<KUser>> users() =>
      _c.get('$_p/users', (d) => _list(d, KUser.fromJson));

  Future<KUser> tambahUser({
    required String name,
    required String username,
    required String password,
    required bool admin,
  }) => _c.post('$_p/users', {
    'name': name,
    'username': username,
    'password': password,
    'role': admin ? 'admin' : 'terapis',
  }, (d) => KUser.fromJson(_map(d)));

  Future<void> hapusUser(String id) => _c.delete('$_p/users/$id', (_) {});

  Future<void> ubahPassword(String id, String password) =>
      _c.put('$_p/users/$id/password', {'password': password}, (_) {});
}
