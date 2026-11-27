import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'klinik_api.dart';
import 'klinik_models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'intake_xray.dart';
import 'k_ui.dart';
import 'widgets.dart';

/// Detail pasien (Laravel detail-pasien): data diri + tabel pemeriksaan (tambah / edit / hapus).
class PasienDetailPage extends ConsumerStatefulWidget {
  const PasienDetailPage({super.key, required this.id, this.initial});
  final String id;

  /// Data dari kartu daftar: header langsung tampil (avatar "terbang" dari kartu) sambil detail dimuat.
  final Pasien? initial;

  @override
  ConsumerState<PasienDetailPage> createState() => _PasienDetailPageState();
}

class _PasienDetailPageState extends ConsumerState<PasienDetailPage> {
  PasienDetail? _d;
  AppError? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final gen = ++_gen;
    setState(() => _error = null);
    try {
      final d = await ref.read(klinikApiProvider).detail(widget.id);
      if (mounted && gen == _gen) setState(() => _d = d);
    } on AppError catch (e) {
      if (mounted && gen == _gen) setState(() => _error = e);
    }
  }

  Future<void> _go(String route, {Object? extra}) async {
    await context.push(route, extra: extra);
    if (mounted) _reload();
  }

  Future<void> _hapusPasien(Pasien p) async {
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
      context.pop();
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    }
  }

  Future<void> _hapusPemeriksaan(Pemeriksaan x) async {
    final ok = await confirmHapus(
      context,
      title: 'Hapus pemeriksaan ${tgl(x.tanggal)}?',
      message: 'Pemeriksaan ini dihapus dari riwayat pasien dan rekap.',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(klinikApiProvider).hapusPemeriksaan(x.id);
      if (!mounted) return;
      context.feedback.success('Data pemeriksaan pasien berhasil dihapus.');
      _reload();
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final p = d?.pasien ?? widget.initial;
    return OlDetailScaffold(
      title: 'Detail Pasien',
      onRefresh: () {
        ref.read(klinikApiProvider).cache.expire('/v1/klinik/pasien/${widget.id}');
        return _reload();
      },
      children: [
        if (p != null)
          _HeroPasien(
            pasien: p,
            jumlahPeriksa: d?.pemeriksaan.length,
            onEdit: () => _go(Routes.klinikEditPasien(p.id)),
            onHapus: () => _hapusPasien(p),
          ),
        if (p != null) _DataDiri(pasien: p),
        if (p != null)
          KFormSection(
            icon: OlIcons.xray,
            title: 'Rontgen / MRI',
            subtitle: 'Terenkripsi, hanya untuk staf',
            children: [IntakeXray.pasien(pasienId: p.id, editable: true)],
          ),
        if (_error != null && d == null)
          OlErrorCard(message: _error!.message, onRetry: _reload)
        else if (d == null)
          const OlLoadingCard()
        else ...[
          Row(
            children: [
              Expanded(child: OlSectionHeader(title: 'Riwayat Pemeriksaan')),
              OlButton(
                label: 'Tambah',
                icon: OlIcons.plus,
                small: true,
                expand: false,
                onPressed: () => _go(Routes.klinikTambahPemeriksaan(d.pasien.id)),
              ),
            ],
          ),
          if (d.pemeriksaan.isEmpty)
            OlCard(
              child: EmptyState(
                illustration: OlIllustration.emptyInbox,
                title: 'Belum ada pemeriksaan',
                message: 'Tidak ada data pemeriksaan pada pasien ini.',
                actionLabel: 'Tambah Pemeriksaan',
                onAction: () => _go(Routes.klinikTambahPemeriksaan(d.pasien.id)),
              ),
            )
          else
            OlAnimatedItems(
              spacing: 0,
              children: [
                for (final (i, x) in d.pemeriksaan.indexed)
                  KeyedSubtree(
                    key: ValueKey(x.id),
                    child: KTimelineTile(
                      first: i == 0,
                      last: i == d.pemeriksaan.length - 1,
                      child: _PemeriksaanCard(
                        data: x,
                        terbaru: i == 0,
                        onEdit: () => _go(Routes.klinikEditPemeriksaan(x.id), extra: x),
                        onHapus: () => _hapusPemeriksaan(x),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _HeroPasien extends StatelessWidget {
  const _HeroPasien({required this.pasien, required this.jumlahPeriksa, required this.onEdit, required this.onHapus});

  final Pasien pasien;
  final int? jumlahPeriksa;
  final VoidCallback onEdit;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final p = pasien;
    return KHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'pasien-avatar-${p.id}',
                child: KAvatar(name: p.nama, size: 64, ring: true),
              ),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nama, style: t.title.copyWith(color: Colors.white, fontSize: 20, height: 1.15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        KPill(nomorPasien(p.nomor), tone: KPillTone.glass, mono: p.nomor != null),
                        KPill(genderLabel(p.gender), tone: KPillTone.glass),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OlSpace.xl),
          KStatRow(
            light: true,
            children: [
              KStat(value: umur(p.ttl), label: 'Umur', suffix: ' th', light: true),
              KStat(value: p.bb?.round(), label: 'Berat', suffix: ' kg', light: true),
              KStat(value: p.tb?.round(), label: 'Tinggi', suffix: ' cm', light: true),
              KStat(value: jumlahPeriksa, label: 'Periksa', suffix: '×', light: true),
            ],
          ),
          const SizedBox(height: OlSpace.lg),
          Row(
            children: [
              KGlassButton(icon: OlIcons.edit, label: 'Edit data', onTap: onEdit),
              const SizedBox(width: OlSpace.sm),
              KGlassButton(icon: OlIcons.archive, label: 'Hapus', onTap: onHapus),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataDiri extends StatelessWidget {
  const _DataDiri({required this.pasien});
  final Pasien pasien;

  @override
  Widget build(BuildContext context) {
    final p = pasien;
    return KFormSection(
      icon: OlIcons.user,
      title: 'Data Diri',
      children: [
        KGrid(
          items: [
            KGridItem(
              KInfoTile(
                icon: OlIcons.calendar,
                label: 'Tanggal lahir',
                value: [if (p.tempatLahir != null) p.tempatLahir!, tgl(p.ttl)].join(', '),
              ),
              wide: true,
            ),
            if (p.tlp != null) KGridItem(KInfoTile(icon: OlIcons.phone, label: 'Telepon', value: p.tlp!), wide: true),
            KGridItem(KInfoTile(icon: OlIcons.pin, label: 'Alamat', value: p.alamat ?? '-'), wide: true),
            KGridItem(KInfoTile(icon: OlIcons.branch, label: 'Instansi', value: p.instansi ?? '-')),
            KGridItem(KInfoTile(icon: OlIcons.exercise, label: 'Hobi / kegiatan', value: p.hobi ?? '-')),
          ],
        ),
      ],
    );
  }
}

class _PemeriksaanCard extends StatelessWidget {
  const _PemeriksaanCard({required this.data, required this.onEdit, required this.onHapus, this.terbaru = false});

  final Pemeriksaan data;
  final VoidCallback onEdit;
  final VoidCallback onHapus;
  final bool terbaru;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final x = data;
    final rontgen = x.hasilRontgen;
    return OlCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, OlSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KDateBadge(date: x.tanggal, highlight: terbaru),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      x.keluhan ?? 'Tanpa keluhan tercatat',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (terbaru) const KPill('Terbaru', tone: KPillTone.ok),
                        KPill(relatif(x.tanggal), icon: OlIcons.clock),
                        if (x.terapis != null) KPill(x.terapis!, icon: OlIcons.user, tone: KPillTone.brand),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  OlIconButton(icon: OlIcons.edit, semanticLabel: 'Edit pemeriksaan', onPressed: onEdit),
                  OlIconButton(icon: OlIcons.archive, semanticLabel: 'Hapus pemeriksaan', onPressed: onHapus),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KTextBlock(
                  icon: OlIcons.alert,
                  label: 'Penyebab · lama cedera',
                  value: [x.penyebab, x.lamaCedera].whereType<String>().join(' · '),
                ),
                KTextBlock(icon: OlIcons.report, label: 'Diagnosa', value: x.analisa),
                KTextBlock(icon: OlIcons.hands, label: 'Treatment', value: x.treatment),
                KTextBlock(icon: OlIcons.body, label: 'Bagian yang ditangani', value: x.bagianPenenang),
                KTextBlock(icon: OlIcons.checkCircle, label: 'Kesimpulan', value: x.kesimpulan),
                KTextBlock(icon: OlIcons.xray, label: 'MRI / Rontgen', value: rontgen),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
