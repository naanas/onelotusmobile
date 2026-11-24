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

/// Tambah / Edit Pemeriksaan (Laravel tambah-pemeriksaan & edit-pemeriksaan).
/// Tambah: [pasienId] (+ [prefill] dari Formulir). Edit: [pemeriksaanId] (+ [editing] bila sudah dimuat).
class PemeriksaanFormPage extends ConsumerStatefulWidget {
  const PemeriksaanFormPage({
    super.key,
    this.pasienId,
    this.prefill,
    this.pemeriksaanId,
    this.editing,
    this.lanjutDetail = false,
  });

  final String? pasienId;
  final PemeriksaanDraft? prefill;
  final int? pemeriksaanId;
  final Pemeriksaan? editing;
  final bool lanjutDetail;

  @override
  ConsumerState<PemeriksaanFormPage> createState() =>
      _PemeriksaanFormPageState();
}

class _PemeriksaanFormPageState extends ConsumerState<PemeriksaanFormPage> {
  final _keluhan = TextEditingController();
  final _penyebab = TextEditingController();
  final _lama = TextEditingController();
  final _analisa = TextEditingController();
  final _treatment = TextEditingController();
  final _bagian = TextEditingController();
  final _kesimpulan = TextEditingController();
  final _terapis = TextEditingController();
  final _rontgen = TextEditingController();
  DateTime? _tanggal;
  bool _busy = false;
  bool _loading = false;
  AppError? _loadError;
  Map<String, String> _errors = {};
  String? _pasienId;

  bool get _edit => widget.pemeriksaanId != null;

  @override
  void initState() {
    super.initState();
    _pasienId = widget.pasienId;
    if (_edit) {
      final e = widget.editing;
      if (e != null) {
        _fill(e);
      } else {
        _loadPemeriksaan();
      }
    } else {
      final p = widget.prefill;
      _keluhan.text = p?.keluhan ?? '';
      _penyebab.text = p?.penyebab ?? '';
      _lama.text = p?.lamaCedera ?? '';
      _rontgen.text = p?.hasilRontgen ?? '';
      // Terapis yang mengisi: nama sendiri sebagai default (bisa diubah).
      final me = ref.read(authProvider).user;
      if (me != null && !me.isAdmin) _terapis.text = me.name;
    }
  }

  void _fill(Pemeriksaan e) {
    _pasienId = e.pasienId;
    _keluhan.text = e.keluhan ?? '';
    _penyebab.text = e.penyebab ?? '';
    _lama.text = e.lamaCedera ?? '';
    _analisa.text = e.analisa ?? '';
    _treatment.text = e.treatment ?? '';
    _bagian.text = e.bagianPenenang ?? '';
    _kesimpulan.text = e.kesimpulan ?? '';
    _terapis.text = e.terapis ?? '';
    _rontgen.text = e.hasilRontgen ?? '';
    _tanggal = e.tanggal;
  }

  Future<void> _loadPemeriksaan() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final e = await ref
          .read(klinikApiProvider)
          .pemeriksaan(widget.pemeriksaanId!);
      if (mounted) setState(() => _fill(e));
    } on AppError catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _keluhan,
      _penyebab,
      _lama,
      _analisa,
      _treatment,
      _bagian,
      _kesimpulan,
      _terapis,
      _rontgen,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTanggal() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? now,
      firstDate: DateTime(2015),
      lastDate: now,
      helpText: 'Tanggal pemeriksaan',
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  String? _v(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final draft = PemeriksaanDraft(
      keluhan: _v(_keluhan),
      penyebab: _v(_penyebab),
      lamaCedera: _v(_lama),
      analisa: _v(_analisa),
      treatment: _v(_treatment),
      bagianPenenang: _v(_bagian),
      kesimpulan: _v(_kesimpulan),
      terapis: _v(_terapis),
      hasilRontgen: _v(_rontgen),
      tglPeriksa: _tanggal,
      bookingId: _edit ? null : widget.prefill?.bookingId,
    );
    setState(() {
      _busy = true;
      _errors = {};
    });
    final api = ref.read(klinikApiProvider);
    try {
      if (_edit) {
        await api.editPemeriksaan(widget.pemeriksaanId!, draft);
        if (!mounted) return;
        context.feedback.success('Data pemeriksaan pasien berhasil diedit.');
        context.pop(true);
      } else {
        await api.tambahPemeriksaan(_pasienId!, draft);
        if (!mounted) return;
        context.feedback.success('Data pemeriksaan pasien berhasil ditambah.');
        // Laravel: setelah simpan tampil detail pasien.
        if (widget.lanjutDetail) {
          context.pushReplacement(Routes.klinikDetail(_pasienId!));
        } else {
          context.pop(true);
        }
      }
    } on AppError catch (e) {
      if (!mounted) return;
      if (e.fieldErrors.isNotEmpty) {
        setState(
          () => _errors = {
            for (final f in e.fieldErrors.entries) f.key: f.value.first,
          },
        );
        context.feedback.info(e.message);
      } else {
        context.feedback.error(e, retry: _save);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final title = _edit ? 'Edit Pemeriksaan' : 'Tambah Pemeriksaan';
    if (_loading || _loadError != null) {
      return OlDetailScaffold(
        title: title,
        children: [
          if (_loadError != null)
            OlErrorCard(message: _loadError!.message, onRetry: _loadPemeriksaan)
          else
            const OlLoadingCard(),
        ],
      );
    }
    Widget field(
      String label,
      TextEditingController ctl,
      String key, {
      int lines = 2,
      String? hint,
    }) => OlTextField(
      label: label,
      controller: ctl,
      maxLines: lines,
      hint: hint,
      error: _errors[key],
    );
    return OlDetailScaffold(
      title: title,
      foot: [OlButton(label: 'Simpan', loading: _busy, onPressed: _save)],
      children: [
        if (widget.prefill != null)
          const OlBanner(
            tone: OlBannerTone.info,
            icon: OlIcons.info,
            message:
                'Keluhan, penyebab, lama cedera, dan keterangan rontgen diisi dari formulir pendaftaran.',
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tanggal Pemeriksaan', style: t.fieldLabel),
            const SizedBox(height: 6),
            OlCard(
              onTap: _pickTanggal,
              semanticLabel: 'Pilih tanggal pemeriksaan',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _tanggal == null
                          ? (_edit ? '-' : 'Hari ini')
                          : tgl(_tanggal),
                      style: t.body,
                    ),
                  ),
                  OlIcon(OlIcons.calendar, color: c.brand),
                ],
              ),
            ),
            if (_errors['tgl_periksa'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _errors['tgl_periksa']!,
                  style: t.caption.copyWith(color: c.crit),
                ),
              ),
          ],
        ),
        field('Keluhan', _keluhan, 'keluhan', lines: 3),
        field('Penyebab Cedera', _penyebab, 'penyebab'),
        field('Lama Cedera', _lama, 'lama_cedera', lines: 1),
        field('Analisa dan Diagnosa', _analisa, 'analisa', lines: 3),
        field('Treatment', _treatment, 'treatment'),
        field('Bagian yang Diberikan Penanganan', _bagian, 'bagian_penenang'),
        field(
          'Kesimpulan dan Rekomendasi',
          _kesimpulan,
          'kesimpulan',
          lines: 3,
        ),
        field('Terapis', _terapis, 'terapis', lines: 1),
        field(
          'Link MRI / Rontgen',
          _rontgen,
          'hasil_rontgen',
          lines: 1,
          hint: 'https://drive.google.com/…',
        ),
      ],
    );
  }
}
