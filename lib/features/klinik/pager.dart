import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'klinik_api.dart';

/// Daftar berhalaman: halaman 1 dimuat di awal, halaman berikutnya saat digulir mendekati bawah
/// ([InfiniteScroll]) atau tombol "Muat lebih banyak". Respons lama yang datang terlambat diabaikan.
class Pager<T> extends ChangeNotifier {
  Pager(this._fetch);

  final Future<KPage<T>> Function(int page) _fetch;
  final items = <T>[];
  int page = 0;
  int total = 0;
  bool hasMore = true;
  bool loading = false;
  AppError? error;
  KPage<T>? first;
  int _gen = 0;
  bool _disposed = false;

  bool get loadedOnce => first != null;

  Future<void> reload() => _load(reset: true);

  Future<void> more() async {
    if (loading || !hasMore || error != null) return;
    await _load();
  }

  Future<void> _load({bool reset = false}) async {
    final gen = reset ? ++_gen : _gen;
    if (reset) {
      page = 0;
      hasMore = true;
    }
    loading = true;
    error = null;
    _notify();
    try {
      final res = await _fetch(page + 1);
      if (gen != _gen || _disposed) return;
      if (reset) items.clear();
      items.addAll(res.items);
      page = res.page;
      total = res.total;
      hasMore = res.hasMore;
      if (res.page == 1) first = res;
    } on AppError catch (e) {
      if (gen == _gen) error = e;
    } catch (e, st) {
      // Bug/format tak terduga: tetap tampilkan error (bukan layar kosong) + catat untuk debug.
      debugPrint('[pager] $e\n$st');
      if (gen == _gen) error = const AppError(ErrorCode.unknown);
    } finally {
      if (gen == _gen) {
        loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Memanggil [onEnd] saat daftar digulir sampai ±600 px dari bawah.
class InfiniteScroll extends StatelessWidget {
  const InfiniteScroll({super.key, required this.onEnd, required this.child});
  final VoidCallback onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: (n) {
      if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) onEnd();
      return false;
    },
    child: child,
  );
}

/// Ekor daftar: memuat / gagal (coba lagi) / tombol muat lebih banyak / akhir daftar.
class PagerFooter extends StatelessWidget {
  const PagerFooter({super.key, required this.pager, this.endLabel});
  final Pager<Object?> pager;
  final String? endLabel;

  @override
  Widget build(BuildContext context) {
    final p = pager;
    if (p.error != null) {
      return OlErrorCard(message: p.error!.message, onRetry: p.items.isEmpty ? p.reload : p.more);
    }
    if (p.loading) return const OlLoadingCard();
    if (p.hasMore && p.items.isNotEmpty) {
      return OlButton.secondary(label: 'Muat lebih banyak', onPressed: p.more);
    }
    if (endLabel != null && p.items.isNotEmpty && p.page > 1) {
      return Center(child: Text(endLabel!, style: context.olText.caption));
    }
    return const SizedBox.shrink();
  }
}

/// Muat ulang diam-diam saat tab terlihat lagi atau aplikasi dibuka kembali (lewat cache: tanpa request bila
/// masih segar, 304 bila tidak ada yang baru).
mixin VisibleReload<W extends StatefulWidget> on State<W> {
  late final AppLifecycleListener _life = AppLifecycleListener(onResume: () {
    if (mounted && _visible) onVisibleAgain();
  });
  bool _visible = true;

  void onVisibleAgain();

  @override
  void initState() {
    super.initState();
    _life;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = TickerMode.of(context);
    if (v && !_visible) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? onVisibleAgain() : null);
    _visible = v;
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }
}
