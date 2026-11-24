import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import 'klinik_api.dart';
import 'klinik_models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'widgets.dart';

/// Data Pasien (Laravel /home): semua pasien terbaru dulu, cari, Detail / Edit / Hapus.
/// Nomor telepon hanya tampil untuk admin.
class PasienListPage extends ConsumerStatefulWidget {
  const PasienListPage({super.key});

  @override
  ConsumerState<PasienListPage> createState() => _PasienListPageState();
}

class _PasienListPageState extends ConsumerState<PasienListPage> {
  final _items = <Pasien>[];
  String _cari = '';
  int _page = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  AppError? _error;
  Timer? _debounce;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final gen = reset ? ++_gen : _gen;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _page = 0;
        _hasMore = true;
      }
    });
    try {
      final res = await ref
          .read(klinikApiProvider)
          .pasien(cari: _cari, page: _page + 1);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.page;
        _total = res.total;
        _hasMore = res.hasMore;
      });
    } on AppError catch (e) {
      if (mounted && gen == _gen) setState(() => _error = e);
    } finally {
      if (mounted && gen == _gen) setState(() => _loading = false);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _cari = v;
      _load(reset: true);
    });
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) _load(reset: true);
  }

  Future<void> _actions(Pasien p) async {
    final pick = await context.feedback.sheet<String>(
      title: p.nama,
      message: '${nomorPasien(p.nomor)} · ${genderLabel(p.gender)}',
      actions: const [
        SheetAction('Detail', 'detail'),
        SheetAction('Edit', 'edit', variant: OlButtonVariant.secondary),
        SheetAction('Hapus', 'hapus', variant: OlButtonVariant.dangerSecondary),
      ],
    );
    if (!mounted) return;
    switch (pick) {
      case 'detail':
        _open(Routes.klinikDetail(p.id));
      case 'edit':
        _open(Routes.klinikEditPasien(p.id));
      case 'hapus':
        await _hapus(p);
    }
  }

  Future<void> _hapus(Pasien p) async {
    final ok = await confirmHapus(
      context,
      title: 'Konfirmasi hapus pasien ${p.nama}',
      message: 'Pasien dan semua pemeriksaannya hilang dari Data Pasien & rekap.',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(klinikApiProvider).hapusPasien(p.id);
      if (!mounted) return;
      context.feedback.success('Data pasien berhasil dihapus.');
      _load(reset: true);
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final admin = ref.watch(authProvider.select((s) => s.user?.isAdmin ?? false));
    return OlPageBody(
      header: OlAppHeader(
        title: 'Data Pasien',
        bottom: OlSearchField(
          hint: admin
              ? 'Cari nama, nomor pasien, alamat, no. HP'
              : 'Cari nama, nomor pasien, alamat',
          onChanged: _onSearch,
        ),
      ),
      onRefresh: () => _load(reset: true),
      children: [
        if (_items.isNotEmpty || (!_loading && _error == null))
          Text(
            _cari.isEmpty
                ? '$_total pasien'
                : '$_total pasien cocok dengan "$_cari"',
            style: t.caption,
          ),
        for (final p in _items)
          _PasienCard(
            pasien: p,
            onTap: () => _open(Routes.klinikDetail(p.id)),
            onMore: () => _actions(p),
          ),
        if (_error != null)
          OlErrorCard(
            message: _error!.message,
            onRetry: () => _load(reset: _items.isEmpty),
          )
        else if (_loading)
          const OlLoadingCard()
        else if (_items.isEmpty)
          OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptySearch,
              title: _cari.isEmpty
                  ? 'Belum ada pasien'
                  : 'Pasien tidak ditemukan',
              message: _cari.isEmpty
                  ? 'Tambah pasien lewat tombol + di bawah.'
                  : 'Coba kata kunci lain, misalnya sebagian nama atau nomor pasien.',
            ),
          )
        else if (_hasMore)
          OlButton.secondary(label: 'Muat lebih banyak', onPressed: _load),
      ],
    );
  }
}

class _PasienCard extends ConsumerWidget {
  const _PasienCard({
    required this.pasien,
    required this.onTap,
    required this.onMore,
  });

  final Pasien pasien;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.olText;
    final c = context.ol;
    final p = pasien;
    return OlCard(
      onTap: onTap,
      semanticLabel: 'Pasien ${p.nama}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nama, style: t.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  [
                    nomorPasien(p.nomor),
                    genderLabel(p.gender),
                    'Lahir ${tgl(p.ttl)}',
                  ].join(' · '),
                  style: t.caption,
                ),
                if (p.tlp != null)
                  Text(p.tlp!, style: t.caption.copyWith(color: c.fg)),
                Text(
                  p.alamat ?? '-',
                  style: t.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  p.kunjunganTerakhir == null
                      ? 'Belum ada pemeriksaan'
                      : 'Kunjungan terakhir ${tgl(p.kunjunganTerakhir)}',
                  style: t.caption.copyWith(
                    color: c.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          OlIconButton(
            icon: OlIcons.more,
            semanticLabel: 'Aksi untuk ${p.nama}',
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}
