import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import 'klinik_api.dart';
import 'klinik_models.dart';
import 'notifikasi.dart';
import 'pager.dart';
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

class _PasienListPageState extends ConsumerState<PasienListPage> with VisibleReload {
  String _cari = '';
  Timer? _debounce;
  final _search = TextEditingController();
  int _formGen = 0;
  late final _pager = Pager<Pasien>(
    (page) => ref.read(klinikApiProvider).pasien(cari: _cari, page: page),
  )..reload();

  @override
  void onVisibleAgain() {
    _pager.reload();
    setState(() => _formGen++);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _pager.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) => reset ? _pager.reload() : _pager.more();

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

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 11
        ? 'Selamat pagi'
        : h < 15
        ? 'Selamat siang'
        : h < 18
        ? 'Selamat sore'
        : 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final admin = user?.isAdmin ?? false;
    final first = user?.firstName;
    return InfiniteScroll(
      onEnd: _pager.more,
      child: ListenableBuilder(
        listenable: _pager,
        builder: (context, _) => _body(context, admin, first),
      ),
    );
  }

  Widget _body(BuildContext context, bool admin, String? first) {
    final t = context.olText;
    final c = context.ol;
    final p = _pager;
    final items = p.items;
    final hint = admin ? 'Cari nama, nomor pasien, alamat, no. HP' : 'Cari nama, nomor pasien, alamat';
    return OlPageBody(
      pinnedHeader: true,
      heroOverlap: true,
      backToTop: true,
      // Kolom cari ikut turun di bawah bar ringkas saat digulir (isi sama dengan kolom di kartu).
      floatingBelow: OlSearchField(hint: hint, controller: _search, onChanged: _onSearch, elevated: true),
      header: OlAppHeader(
        hero: true,
        title: first == null ? _greeting() : '${_greeting()}, $first',
        context_: 'One Lotus · ${admin ? 'Admin' : 'Terapis'}',
        actions: const [StaffNotifBell()],
      ),
      onRefresh: () async {
        ref.read(klinikApiProvider).cache.expire();
        setState(() => _formGen++);
        await _pager.reload();
      },
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Data Pasien', style: t.heading),
              const SizedBox(height: 2),
              Text(
                !p.loadedOnce
                    ? 'Memuat…'
                    : _cari.isEmpty
                    ? '${p.total} pasien terdaftar'
                    : '${p.total} pasien cocok dengan "$_cari"',
                style: t.body.copyWith(color: c.muted),
              ),
              const SizedBox(height: OlSpace.md),
              OlSearchField(hint: hint, controller: _search, onChanged: _onSearch),
            ],
          ),
        ),
        _FormulirBanner(key: ValueKey(_formGen)),
        if (items.isNotEmpty) const OlSectionHeader(title: 'Pasien terbaru'),
        for (final x in items)
          _PasienCard(
            pasien: x,
            onTap: () => _open(Routes.klinikDetail(x.id)),
            onMore: () => _actions(x),
          ),
        if (p.loadedOnce && items.isEmpty && p.error == null)
          OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptySearch,
              title: _cari.isEmpty ? 'Belum ada pasien' : 'Pasien tidak ditemukan',
              message: _cari.isEmpty
                  ? 'Tambah pasien lewat tombol + di bawah.'
                  : 'Coba kata kunci lain, misalnya sebagian nama atau nomor pasien.',
            ),
          ),
        PagerFooter(pager: p, endLabel: 'Semua ${p.total} pasien sudah tampil'),
      ],
    );
  }
}

/// "N formulir menunggu persetujuan" → tab Formulir (seperti kartu ringkas di beranda pasien).
class _FormulirBanner extends ConsumerStatefulWidget {
  const _FormulirBanner({super.key});

  @override
  ConsumerState<_FormulirBanner> createState() => _FormulirBannerState();
}

class _FormulirBannerState extends ConsumerState<_FormulirBanner> {
  late final Future<int> _count = ref.read(klinikApiProvider).formulirCount().catchError((_) => 0);

  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: _count,
    builder: (context, snap) {
      final n = snap.data ?? 0;
      if (n == 0) return const SizedBox.shrink();
      final c = context.ol;
      final t = context.olText;
      return OlCard(
        onTap: () => context.go(Routes.klinikFormulir),
        semanticLabel: '$n formulir menunggu persetujuan',
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
              child: Center(child: OlIcon(OlIcons.receipt, color: c.brand)),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$n formulir menunggu', style: t.bodyStrong),
                  Text(
                    'Setujui supaya pasien mendapat nomor pasien.',
                    style: t.caption,
                  ),
                ],
              ),
            ),
            OlIcon(OlIcons.chevronRight, color: c.muted),
          ],
        ),
      );
    },
  );
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
          OlAvatar(name: p.nama),
          const SizedBox(width: OlSpace.md),
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
