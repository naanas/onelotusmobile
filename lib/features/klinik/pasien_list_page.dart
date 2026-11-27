import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import 'k_ui.dart';
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
  late final _pager = Pager<Pasien>((page) => ref.read(klinikApiProvider).pasien(cari: _cari, page: page))..reload();

  @override
  void onVisibleAgain() {
    _pager.refresh();
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

  Future<void> _open(String route, {Object? extra}) async {
    await context.push(route, extra: extra);
    if (mounted) _pager.refresh();
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
      child: ListenableBuilder(listenable: _pager, builder: (context, _) => _body(context, admin, first)),
    );
  }

  Widget _body(BuildContext context, bool admin, String? first) {
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
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: OlIcons.users,
                      label: _cari.isEmpty ? 'Pasien terdaftar' : 'Hasil pencarian',
                      value: p.loadedOnce ? p.total : null,
                    ),
                  ),
                  const SizedBox(width: OlSpace.sm),
                  Expanded(child: _FormulirTile(key: ValueKey(_formGen))),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              OlSearchField(hint: hint, controller: _search, onChanged: _onSearch),
            ],
          ),
        ),
        if (items.isNotEmpty)
          Row(
            children: [
              Expanded(child: OlSectionHeader(title: _cari.isEmpty ? 'Pasien terbaru' : 'Hasil untuk "$_cari"')),
              KPill('${items.length} dari ${p.total}', tone: KPillTone.muted),
            ],
          ),
        if (items.isNotEmpty)
          OlAnimatedItems(
            children: [
              for (final x in items)
                KeyedSubtree(
                  key: ValueKey(x.id),
                  child: _PasienCard(
                    pasien: x,
                    onTap: () => _open(Routes.klinikDetail(x.id), extra: x),
                    onMore: () => _actions(x),
                  ),
                ),
            ],
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

/// Kotak statistik kecil di kartu atas.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
    this.onTap,
    this.pulse = false,
  });
  final OlIconData icon;
  final String label;
  final int? value;
  final (Color, Color)? tone;
  final VoidCallback? onTap;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final (bg, fg) = tone ?? (c.brandSoft, c.brand);
    final box = AnimatedContainer(
      duration: OlMotion.of(context, OlMotion.slow),
      padding: const EdgeInsets.all(OlSpace.md),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OlIcon(icon, size: 18, color: fg, weight: OlIconWeight.duotone),
              const Spacer(),
              if (pulse) KPulseDot(color: fg, size: 7),
              if (onTap != null) OlIcon(OlIcons.chevronRight, size: 16, color: fg),
            ],
          ),
          const SizedBox(height: 8),
          value == null
              ? const Skeleton(width: 48, height: 22)
              : OlCountUp(value!, style: t.title.copyWith(fontSize: 24, color: fg, height: 1.1)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    return onTap == null ? box : OlPressable(onTap: onTap, child: box);
  }
}

/// Jumlah formulir menunggu persetujuan → tab Formulir. Berdenyut bila ada yang menunggu.
class _FormulirTile extends ConsumerStatefulWidget {
  const _FormulirTile({super.key});

  @override
  ConsumerState<_FormulirTile> createState() => _FormulirTileState();
}

class _FormulirTileState extends ConsumerState<_FormulirTile> {
  late final Future<int> _count = ref.read(klinikApiProvider).formulirCount().catchError((_) => 0);

  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: _count,
    builder: (context, snap) {
      final c = context.ol;
      final n = snap.data;
      final ada = (n ?? 0) > 0;
      return _StatTile(
        icon: OlIcons.receipt,
        label: ada ? 'Formulir menunggu' : 'Formulir beres',
        value: n,
        tone: ada ? (c.warnSoft, c.warn) : (c.okSoft, c.ok),
        pulse: ada,
        onTap: () => context.go(Routes.klinikFormulir),
      );
    },
  );
}

class _PasienCard extends ConsumerWidget {
  const _PasienCard({required this.pasien, required this.onTap, required this.onMore});

  final Pasien pasien;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.olText;
    final c = context.ol;
    final p = pasien;
    final u = umur(p.ttl);
    return OlCard(
      onTap: onTap,
      semanticLabel: 'Pasien ${p.nama}',
      padding: const EdgeInsets.fromLTRB(OlSpace.lg, 14, 6, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'pasien-avatar-${p.id}',
            child: KAvatar(name: p.nama),
          ),
          const SizedBox(width: OlSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nama,
                  style: t.bodyStrong.copyWith(fontSize: 15.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    KPill(
                      p.nomor == null ? 'Belum bernomor' : 'No. ${p.nomor}',
                      tone: KPillTone.brand,
                      mono: p.nomor != null,
                    ),
                    KPill([genderLabel(p.gender), if (u != null) '$u th'].join(' · ')),
                  ],
                ),
                if (p.tlp != null) KMeta(OlIcons.phone, p.tlp!, color: c.fg),
                KMeta(OlIcons.pin, p.alamat ?? '-'),
                const SizedBox(height: 10),
                Container(height: 1, color: c.line),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.kunjunganTerakhir == null ? c.faint : c.ok,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.kunjunganTerakhir == null
                            ? 'Belum ada pemeriksaan'
                            : 'Terakhir periksa ${relatif(p.kunjunganTerakhir).toLowerCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(
                          color: p.kunjunganTerakhir == null ? c.muted : c.ok,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (p.jumlahPemeriksaan > 0)
                      Text('${p.jumlahPemeriksaan}× periksa', style: t.caption.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          OlIconButton(icon: OlIcons.more, semanticLabel: 'Aksi untuk ${p.nama}', onPressed: onMore),
        ],
      ),
    );
  }
}
