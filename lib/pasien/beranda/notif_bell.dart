import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/pasien/pasien_app_api.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

/// Lonceng notifikasi di kanan atas header Beranda (posisi aksi header di semua halaman OneLotus),
/// dengan badge jumlah belum dibaca. Badge dimuat ulang saat Beranda tampil lagi, aplikasi dibuka
/// kembali, dan tiap menit selama Beranda terlihat. Gagal memuat → lonceng tanpa badge.
class PasienNotifBell extends ConsumerStatefulWidget {
  const PasienNotifBell({super.key});

  @override
  ConsumerState<PasienNotifBell> createState() => _PasienNotifBellState();
}

class _PasienNotifBellState extends ConsumerState<PasienNotifBell> {
  late final AppLifecycleListener _life;
  Timer? _tick;
  bool _visible = true;
  int _last = 0;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _refresh);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible && !_visible) WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _visible = visible;
  }

  void _refresh() {
    if (mounted && _visible) ref.invalidate(pasienUnreadProvider);
  }

  @override
  void dispose() {
    _life.dispose();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    await context.push(PRoutes.notifikasi);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Selama memuat ulang, angka terakhir tetap tampil (tanpa kedip).
    final n = ref.watch(pasienUnreadProvider).whenOrNull(data: (v) => v);
    if (n != null) _last = n;
    return OlIconButton(
      icon: OlIcons.bell,
      semanticLabel: 'Notifikasi',
      onHero: true,
      badge: _last,
      onPressed: _open,
    );
  }
}
