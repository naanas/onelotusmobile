import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/klinik_api.dart';
import '../data/models.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../ui/ui.dart';
import 'widgets.dart';

/// Detail pasien (Laravel detail-pasien): data diri + tabel pemeriksaan (tambah / edit / hapus).
class PasienDetailPage extends ConsumerStatefulWidget {
  const PasienDetailPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<PasienDetailPage> createState() => _PasienDetailPageState();
}

class _PasienDetailPageState extends ConsumerState<PasienDetailPage> {
  int _gen = 0;

  void _reload() => setState(() => _gen++);

  Future<void> _go(String route, {Object? extra}) async {
    await context.push(route, extra: extra);
    if (mounted) _reload();
  }

  Future<void> _hapusPasien(Pasien p) async {
    final ok = await confirmHapus(
      context,
      title: 'Konfirmasi hapus pasien ${p.nama}',
      message: 'Data pasien beserta semua pemeriksaannya dihapus permanen.',
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

  Future<void> _hapusPemeriksaan(Perawatan x) async {
    final ok = await confirmHapus(
      context,
      title: 'Hapus pemeriksaan ${tgl(x.tanggal)}?',
      message: 'Pemeriksaan ini dihapus dari riwayat pasien dan rekap.',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(klinikApiProvider).hapusPerawatan(x.id);
      if (!mounted) return;
      context.feedback.success('Data pemeriksaan pasien berhasil dihapus.');
      _reload();
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OlDetailScaffold(
      title: 'Detail Pasien',
      onRefresh: () async => _reload(),
      children: [
        OlAsync<PasienDetail>(
          key: ValueKey(_gen),
          load: () => ref.read(klinikApiProvider).detail(widget.id),
          builder: (context, d, _) {
            final p = d.pasien;
            return [
              _DataPasien(
                pasien: p,
                onEdit: () => _go(Routes.editPasien(p.id)),
                onHapus: () => _hapusPasien(p),
              ),
              OlSectionHeader(
                title: 'Pemeriksaan (${d.perawatan.length})',
                actionLabel: '+ Tambah',
                onAction: () => _go(Routes.tambahPemeriksaan(p.id)),
              ),
              if (d.perawatan.isEmpty)
                OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptyInbox,
                    title: 'Belum ada pemeriksaan',
                    message: 'Tidak ada data pemeriksaan pada pasien ini.',
                    actionLabel: 'Tambah Pemeriksaan',
                    onAction: () => _go(Routes.tambahPemeriksaan(p.id)),
                  ),
                )
              else
                for (final x in d.perawatan)
                  _PemeriksaanCard(
                    data: x,
                    onEdit: () => _go(Routes.editPemeriksaan(x.id), extra: x),
                    onHapus: () => _hapusPemeriksaan(x),
                  ),
            ];
          },
        ),
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
      ('Nomor Pasien', '${p.nomor}'),
      ('Nama', p.nama),
      (
        'Tanggal Lahir',
        [if (p.tempatLahir != null) p.tempatLahir!, tgl(p.ttl)].join(', '),
      ),
      if (p.tlp != null) ('Nomor Telepon', p.tlp!),
      ('Alamat', p.alamat),
      ('Berat Badan', p.bb == null ? '-' : '${p.bb} kg'),
      ('Tinggi Badan', p.tb == null ? '-' : '${p.tb} cm'),
      ('Jenis Kelamin', genderLabel(p.gender)),
      ('Instansi', p.instansi.isEmpty ? '-' : p.instansi),
      ('Hobi / Kegiatan', p.hobi ?? '-'),
    ];
    return OlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.nama, style: context.olText.heading),
          const SizedBox(height: OlSpace.sm),
          for (final (i, r) in rows.indexed)
            OlInfoRow(label: r.$1, value: r.$2, divider: i < rows.length - 1),
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

  final Perawatan data;
  final VoidCallback onEdit;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
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
          if (rontgen != null && rontgen != '-')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: rontgen));
                  context.feedback.info(
                    'Link MRI/Rontgen disalin. Tempel di browser untuk membuka.',
                  );
                },
                icon: OlIcon(OlIcons.xray, size: 18, color: c.brand),
                label: Text(
                  'Salin link MRI/Rontgen',
                  style: t.bodyStrong.copyWith(color: c.brand),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
