import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'feedback/app_error.dart';
import 'ol_button.dart';
import 'ol_card.dart';
import 'ol_refresh.dart';
import 'skeleton.dart';

/// Memuat data dari server untuk satu layar: skeleton saat memuat, pesan error + "Coba lagi"
/// (ST-03), lalu [builder]. [reload] memuat ulang (mis. setelah aksi berhasil).
///
/// Data selalu segar tanpa tarik manual (stale-while-revalidate): saat layar terlihat lagi —
/// pindah tab, kembali dari layar lain, atau aplikasi dibuka lagi dari latar belakang —
/// data dimuat ulang diam-diam. Data lama tetap tampil selama menunggu; gagal → data lama dipakai.
class OlAsync<T> extends StatefulWidget {
  const OlAsync({super.key, required this.load, required this.builder, this.initialData});

  /// Data tersimpan (cache) yang langsung ditampilkan tanpa skeleton selama [load] berjalan.
  /// Gagal memuat ulang → data ini tetap tampil.
  final T? initialData;

  /// Jeda minimum antar-refresh otomatis (hindari dobel saat beberapa pemicu datang bersamaan).
  /// Diukur dengan jam nyata; tes boleh menurunkannya.
  @visibleForTesting
  static Duration minRefreshGap = const Duration(seconds: 2);

  final Future<T> Function() load;
  final List<Widget> Function(BuildContext context, T data, VoidCallback reload)
  builder;

  @override
  State<OlAsync<T>> createState() => _OlAsyncState<T>();
}

class _OlAsyncState<T> extends State<OlAsync<T>> {
  late Future<T> _future = _first();

  Future<T> _first() {
    final seed = widget.initialData;
    if (seed == null) return _track(widget.load());
    _last = seed;
    _hasLast = true;
    return _track(widget.load()).catchError((Object _) => seed);
  }
  VoidCallback? _unregister;
  late final AppLifecycleListener _life;

  /// Data terakhir yang berhasil dimuat (cadangan saat refresh diam-diam gagal).
  T? _last;
  bool _hasLast = false;
  DateTime _loadedAt = DateTime.now();
  bool _visible = true;


  Future<T> _track(Future<T> f) {
    _loadedAt = DateTime.now();
    return f.then((v) {
      _last = v;
      _hasLast = true;
      return v;
    });
  }

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: () {
      if (_visible) _refreshSilently();
    });
  }

  /// Muat ulang tanpa skeleton/error bila sudah ada data.
  /// [inBuild]: dipanggil dari didChangeDependencies — widget memang akan dibangun ulang, tanpa setState.
  void _refreshSilently({bool inBuild = false}) {
    if (!mounted || DateTime.now().difference(_loadedAt) < OlAsync.minRefreshGap) return;
    var next = _track(widget.load());
    if (_hasLast) {
      final prev = _last as T;
      next = next.catchError((Object _) => prev);
    }
    if (inBuild) {
      _future = next;
    } else {
      setState(() {
        _future = next;
      });
    }
  }

  void _reload() => setState(() {
    _future = _track(widget.load());
  });

  /// Tarik-untuk-memuat-ulang. FutureBuilder tetap menampilkan data lama selama menunggu
  /// (tanpa kedip ke skeleton); indikator tarik berhenti saat future ini selesai.
  Future<void> _pull() {
    final next = _track(widget.load());
    setState(() {
      _future = next;
    });
    return next;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unregister?.call();
    _unregister = OlRefreshScope.maybeOf(context)?.register(_pull);
    // Tab tak aktif & layar yang tertutup layar lain berjalan dengan TickerMode mati.
    final visible = TickerMode.of(context);
    if (visible && !_visible) _refreshSilently(inBuild: true);
    _visible = visible;
  }

  @override
  void dispose() {
    _life.dispose();
    _unregister?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    initialData: widget.initialData,
    builder: (context, snap) {
      final Widget child;
      if (snap.hasError) {
        final e = snap.error;
        child = OlErrorCard(
          message: e is AppError ? e.message : 'Data belum bisa dimuat.',
          refId: e is AppError ? e.refId : null,
          onRetry: _reload,
        );
      } else if (!snap.hasData) {
        child = const OlLoadingCard();
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, w)
                in widget
                    .builder(context, snap.data as T, _reload)
                    .indexed) ...[
              if (i > 0) const SizedBox(height: OlSpace.lg),
              w,
            ],
          ],
        );
      }
      return child;
    },
  );
}

class OlLoadingCard extends StatelessWidget {
  const OlLoadingCard({super.key});

  @override
  Widget build(BuildContext context) => const OlCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(width: 180, height: 16),
        SizedBox(height: 10),
        Skeleton(height: 12),
        SizedBox(height: 18),
        Skeleton(width: 150, height: 16),
        SizedBox(height: 10),
        Skeleton(height: 12),
      ],
    ),
  );
}

class OlErrorCard extends StatelessWidget {
  const OlErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    this.refId,
  });

  final String message;
  final String? refId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return OlCard(
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: context.ol.muted),
          ),
          if (refId != null) ...[
            const SizedBox(height: 4),
            Text(
              'Kode: $refId',
              style: t.mono.copyWith(color: context.ol.faint),
            ),
          ],
          const SizedBox(height: OlSpace.md),
          OlButton(label: 'Coba lagi', expand: false, onPressed: onRetry),
        ],
      ),
    );
  }
}
