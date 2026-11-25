import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'klinik_api.dart';
import 'klinik_models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'intake_xray.dart';
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
          _DataPasien(
            pasien: p,
            onEdit: () => _go(Routes.klinikEditPasien(p.id)),
            onHapus: () => _hapusPasien(p),
          ),
        if (_error != null && d == null)
          OlErrorCard(message: _error!.message, onRetry: _reload)
        else if (d == null)
          const OlLoadingCard()
        else ...[
          OlSectionHeader(
            title: 'Pemeriksaan (${d.pemeriksaan.length})',
            actionLabel: '+ Tambah',
            onAction: () => _go(Routes.klinikTambahPemeriksaan(d.pasien.id)),
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
            OlAnimatedItems(children: [
              for (final x in d.pemeriksaan)
                KeyedSubtree(
                  key: ValueKey(x.id),
                  child: _PemeriksaanCard(
                    data: x,
                    onEdit: () => _go(Routes.klinikEditPemeriksaan(x.id), extra: x),
                    onHapus: () => _hapusPemeriksaan(x),
                  ),
                ),
            ]),
        ],
      ],
    );
  }
}

class _DataPasien extends StatelessWidget {
  const _DataPasien({
    required this.pasien,
    required this.onEdit,
    required this.onHapus,
  });

  final Pasien pasien;
  final VoidCallback onEdit;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final p = pasien;
    final rows = <(String, String)>[
      ('Nomor Pasien', p.nomor == null ? '-' : '${p.nomor}'),
      ('Nama', p.nama),
      (
        'Tanggal Lahir',
        [if (p.tempatLahir != null) p.tempatLahir!, tgl(p.ttl)].join(', '),
      ),
      if (p.tlp != null) ('Nomor Telepon', p.tlp!),
      ('Alamat', p.alamat ?? '-'),
      ('Berat Badan', p.bb == null ? '-' : '${fmtNum(p.bb!)} kg'),
      ('Tinggi Badan', p.tb == null ? '-' : '${fmtNum(p.tb!)} cm'),
      ('Jenis Kelamin', genderLabel(p.gender)),
      ('Instansi', p.instansi ?? '-'),
      ('Hobi / Kegiatan', p.hobi ?? '-'),
    ];
    return OlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Hero(tag: 'pasien-avatar-${p.id}', child: OlAvatar(name: p.nama, large: true)),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nama, style: context.olText.heading),
                    const SizedBox(height: 2),
                    Text(
                      [nomorPasien(p.nomor), genderLabel(p.gender)].join(' · '),
                      style: context.olText.mono.copyWith(fontSize: 13.5, color: context.ol.muted),
                    ),
                    if (p.kunjunganTerakhir != null)
                      Text(
                        'Kunjungan terakhir ${tgl(p.kunjunganTerakhir)}',
                        style: context.olText.caption.copyWith(color: context.ol.brand, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OlSpace.md),
          for (final (i, r) in rows.indexed)
            OlInfoRow(label: r.$1, value: r.$2, divider: i < rows.length - 1),
          IntakeXray.pasien(pasienId: p.id, editable: true),
          const SizedBox(height: OlSpace.md),
          Row(
            children: [
              Expanded(
                child: OlButton.secondary(label: 'Edit', onPressed: onEdit),
              ),
              const SizedBox(width: OlSpace.sm),
              Expanded(
                child: OlButton(
                  label: 'Hapus',
                  variant: OlButtonVariant.dangerSecondary,
                  onPressed: onHapus,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PemeriksaanCard extends StatelessWidget {
  const _PemeriksaanCard({
    required this.data,
    required this.onEdit,
    required this.onHapus,
  });

  final Pemeriksaan data;
  final VoidCallback onEdit;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final x = data;
    final rontgen = x.hasilRontgen;
    return OlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(tgl(x.tanggal), style: t.bodyStrong)),
              OlIconButton(
                icon: OlIcons.edit,
                semanticLabel: 'Edit pemeriksaan',
                onPressed: onEdit,
              ),
              OlIconButton(
                icon: OlIcons.archive,
                semanticLabel: 'Hapus pemeriksaan',
                onPressed: onHapus,
              ),
            ],
          ),
          LabelValue('Keluhan', x.keluhan),
          LabelValue('Penyebab', x.penyebab),
          LabelValue('Lama Cedera', x.lamaCedera),
          LabelValue('Diagnosa', x.analisa),
          LabelValue('Treatment', x.treatment),
          LabelValue('Bagian yang ditangani', x.bagianPenenang),
          LabelValue('Kesimpulan', x.kesimpulan),
          LabelValue('Terapis', x.terapis),
          LabelValue('MRI / Rontgen', rontgen == '-' ? null : rontgen),
        ],
      ),
    );
  }
}
