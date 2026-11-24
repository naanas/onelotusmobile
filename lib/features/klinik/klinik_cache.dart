import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/auth/auth_controller.dart';

/// Cache respons GET menu staf (per alamat + query) supaya tidak selalu memanggil server:
/// - Masih segar (< [ttl]) → langsung dari memori, tanpa request.
/// - Sudah lewat → request bersyarat (ETag); server menjawab 304 bila tidak ada yang baru → isi lama dipakai.
/// - Staf mengubah data (tambah/edit/hapus/setujui) atau ada notifikasi booking baru → [expire] semua.
/// - Tarik untuk muat ulang → [expire] dulu, lalu revalidasi ETag (data tetap utuh bila tidak berubah).
/// Cache hanya di memori; logout / tutup aplikasi = kosong.
class KlinikCache {
  KlinikCache({this.ttl = const Duration(seconds: 60)});

  final Duration ttl;
  final _items = <String, _Entry>{};

  /// Ambil [path] (+[query]) lewat [client]; [parse] menerima isi mentah (`{data, meta}`).
  Future<T> get<T>(
    ApiClient client,
    String path,
    T Function(dynamic body) parse, {
    Map<String, dynamic>? query,
  }) async {
    final key = _key(path, query);
    final hit = _items[key];
    if (hit != null && hit.fresh(ttl)) return parse(hit.body);
    final r = await client.getConditional(path, query: query, etag: hit?.etag);
    if (r.notModified && hit != null) {
      hit.at = DateTime.now();
      return parse(hit.body);
    }
    _items[key] = _Entry(r.body, r.etag);
    if (_items.length > 200) _items.remove(_items.keys.first);
    return parse(r.body);
  }

  /// Tandai semua sudah lewat (berikutnya revalidasi ETag). [prefix] = hanya alamat berawalan itu.
  void expire([String? prefix]) {
    for (final e in _items.entries) {
      if (prefix == null || e.key.startsWith(prefix)) e.value.at = DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  void clear() => _items.clear();

  static String _key(String path, Map<String, dynamic>? q) {
    if (q == null || q.isEmpty) return path;
    final keys = q.keys.where((k) => q[k] != null).toList()..sort();
    return '$path?${keys.map((k) => '$k=${q[k]}').join('&')}';
  }
}

class _Entry {
  _Entry(this.body, this.etag) : at = DateTime.now();
  final dynamic body;
  final String? etag;
  DateTime at;

  bool fresh(Duration ttl) => DateTime.now().difference(at) < ttl;
}

/// Cache baru tiap ganti akun (admin & terapis menerima isi berbeda).
final klinikCacheProvider = Provider<KlinikCache>((ref) {
  ref.watch(authProvider.select((s) => s.user?.id));
  return KlinikCache();
});
