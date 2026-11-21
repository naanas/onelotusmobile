import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/klinik_api.dart';
import '../data/models.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../ui/ui.dart';
import 'widgets.dart';

/// Formulir (Laravel result-form): kiriman form pendaftaran web, terbaru dulu.
/// "Tambah Pasien" → data pasien dibuat → Tambah Pemeriksaan terisi keluhan dari formulir.
/// Yang sudah ditambahkan: "Data sudah ditambahkan".
class FormulirPage extends ConsumerStatefulWidget {
  const FormulirPage({super.key});

  @override
  ConsumerState<FormulirPage> createState() => _FormulirPageState();
}

class _FormulirPageState extends ConsumerState<FormulirPage> {
  int _gen = 0;
  int? _busyId;
  String _cari = '';

  void _reload() => setState(() => _gen++);

  Future<void> _tambah(Formulir f) async {
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: 'Tambah ${f.nama} sebagai pasien?',
        message:
            'Data diri dari formulir disimpan sebagai pasien baru, lalu form pemeriksaan pertama dibuka.',
        confirmLabel: 'Tambah Pasien',
        danger: false,
      ),
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = f.id);
    try {
      final r = await ref.read(klinikApiProvider).tambahDariFormulir(f.id);
      if (!mounted) return;
      context.feedback.success('Data pasien berhasil dibuat.');
      await context.push(
        Routes.tambahPemeriksaan(r.pasienId, lanjutDetail: true),
        extra: r.prefill,
      );
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
        _reload();
      }
    }
  }

  bool _match(Formulir f) {
    final q = _cari.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      f.nama,
      f.alamat,
      f.timestamp,
      f.tempatLahir ?? '',
      genderLabel(f.jenisKelamin),
    ].any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return OlPageBody(
      header: OlAppHeader(
        title: 'Hasil Formulir Pasien',
        bottom: OlSearchField(
          hint: 'Cari nama, alamat, tanggal daftar',
          onChanged: (v) => setState(() => _cari = v),
        ),
      ),
      onRefresh: () async => _reload(),
      children: [
        OlAsync<List<Formulir>>(
          key: ValueKey(_gen),
          load: () => ref.read(klinikApiProvider).formulir(),
          builder: (context, all, _) {
            final list = all.where(_match).toList();
            final baru = all.where((f) => !f.sudahDitambahkan).length;
            return [
              Text(
                '${all.length} formulir · $baru belum ditambahkan',
                style: t.caption,
              ),
              if (list.isEmpty)
                OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptyInbox,
                    title: all.isEmpty
                        ? 'Belum ada formulir'
                        : 'Tidak ditemukan',
                    message: all.isEmpty
                        ? 'Kiriman dari web formulir pendaftaran pasien akan muncul di sini.'
                        : 'Coba kata kunci lain.',
                  ),
                )
              else
                for (final (i, f) in list.indexed)
                  _FormulirCard(
                    no: i + 1,
                    data: f,
                    busy: _busyId == f.id,
                    onTambah: _busyId == null ? () => _tambah(f) : null,
                    onBuka: f.pasienId == null
                        ? null
                        : () => context.push(Routes.detail(f.pasienId!)),
                  ),
            ];
          },
        ),
      ],
    );
  }
}

class _FormulirCard extends StatelessWidget {
  const _FormulirCard({
    required this.no,
    required this.data,
    required this.busy,
    this.onTambah,
    this.onBuka,
  });

  final int no;
  final Formulir data;
  final bool busy;
  final VoidCallback? onTambah;
  final VoidCallback? onBuka;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final f = data;
    final bbtb = [
      f.beratBadan == null ? '-' : '${f.beratBadan} kg',
      f.tinggiBadan == null ? '-' : '${f.tinggiBadan} cm',
    ].join(' / ');
    return OlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('$no. ${f.nama}', style: t.bodyStrong)),
              if (f.sudahDitambahkan)
                const OlTag('Sudah ditambahkan', tone: OlTagTone.ok),
            ],
          ),
          Text('Tgl. daftar ${f.timestamp}', style: t.caption),
          const SizedBox(height: OlSpace.xs),
          LabelValue('Alamat', f.alamat),
          LabelValue(
            'Tempat/Tgl. Lahir',
            [
              if (f.tempatLahir != null) f.tempatLahir!,
              tgl(f.tanggalLahir),
            ].join(', '),
          ),
          LabelValue('No. HP', f.nomorTelepon),
          LabelValue('Jenis Kelamin', genderLabel(f.jenisKelamin)),
          LabelValue('BB / TB', bbtb),
          LabelValue('Instansi Pekerjaan', f.instansi),
          LabelValue('Hobi/Kegiatan', f.hobi),
          LabelValue('Keluhan / Cedera', f.keluhan),
          LabelValue('Penyebab Cedera', f.penyebabCedera),
          LabelValue('Lama Cedera', f.lamaCedera),
          LabelValue('MRI atau Rontgen', f.rontgen),
          const SizedBox(height: OlSpace.md),
          if (f.sudahDitambahkan)
            OlButton.secondary(
              label: 'Data sudah ditambahkan · Buka pasien',
              onPressed: onBuka,
            )
          else
            OlButton(
              label: 'Tambah Pasien',
              loading: busy,
              onPressed: onTambah,
            ),
        ],
      ),
    );
  }
}
