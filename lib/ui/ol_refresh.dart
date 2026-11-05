import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tarik-untuk-memuat-ulang untuk satu layar (dipasang oleh [OlPageBody] & [OlDetailScaffold]).
/// Semua [OlAsync] di dalamnya mendaftar otomatis dan dimuat ulang bersamaan; layar yang memuat
/// data dengan cara lain memberi [onRefresh]. Indikator berhenti setelah semua pemuatan selesai.
class OlRefreshable extends StatefulWidget {
  const OlRefreshable({super.key, required this.child, this.onRefresh});

  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  State<OlRefreshable> createState() => _OlRefreshableState();
}

class _OlRefreshableState extends State<OlRefreshable> {
  final _loaders = <Future<void> Function()>{};

  Future<void> _refresh() async {
    final jobs = [
      for (final f in _loaders.toList()) f(),
      if (widget.onRefresh != null) widget.onRefresh!(),
    ];
    // Error ditampilkan oleh masing-masing pemuat (kartu "Coba lagi"); indikator cukup berhenti.
    await Future.wait(jobs.map((f) => f.catchError((Object _) {})));
  }

  @override
  Widget build(BuildContext context) => OlRefreshScope._(
    loaders: _loaders,
    child: RefreshIndicator(
      onRefresh: _refresh,
      color: context.ol.brand,
      backgroundColor: context.ol.surface,
      child: widget.child,
    ),
  );
}

/// Daftar pemuat data di layar terdekat. [OlAsync] mendaftarkan diri lewat [register].
class OlRefreshScope extends InheritedWidget {
  const OlRefreshScope._({required this.loaders, required super.child});

  final Set<Future<void> Function()> loaders;

  static OlRefreshScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OlRefreshScope>();

  /// Daftarkan pemuat; kembalikan fungsi untuk membatalkan pendaftaran.
  VoidCallback register(Future<void> Function() loader) {
    loaders.add(loader);
    return () => loaders.remove(loader);
  }

  @override
  bool updateShouldNotify(OlRefreshScope oldWidget) => false;
}

/// Fisika gulir yang selalu bisa ditarik walau isi layar pendek (agar tarik-untuk-muat-ulang jalan).
const olRefreshPhysics = AlwaysScrollableScrollPhysics();
