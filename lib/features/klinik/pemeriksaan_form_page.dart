import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import 'klinik_api.dart';
import 'klinik_models.dart';
import '../../router/routes.dart';
import '../../ui/ui.dart';
import 'intake_xray.dart';
import 'k_ui.dart';
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
  ConsumerState<PemeriksaanFormPage> createState() => _PemeriksaanFormPageState();
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

  List<TextEditingController> get _ctls => [
    _keluhan,
    _penyebab,
    _lama,
    _analisa,
    _treatment,
    _bagian,
    _kesimpulan,
    _terapis,
    _rontgen,
  ];

  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    for (final c in _ctls) {
      c.addListener(_changed);
    }
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
      final e = await ref.read(klinikApiProvider).pemeriksaan(widget.pemeriksaanId!);
      if (mounted) setState(() => _fill(e));
    } on AppError catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _ctls) {
      c.removeListener(_changed);
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

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

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
        setState(() => _errors = {for (final f in e.fieldErrors.entries) f.key: f.value.first});
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
      OlIconData? icon,
    }) => OlTextField(label: label, icon: icon, controller: ctl, maxLines: lines, hint: hint, error: _errors[key]);
    int n(List<TextEditingController> cs) => cs.where((x) => x.text.trim().isNotEmpty).length;
    final keluhanN = n([_keluhan, _penyebab, _lama]);
    final tanganN = n([_analisa, _treatment, _bagian]);
    final tutupN = n([_kesimpulan, _terapis]);
    final filled = keluhanN + tanganN + tutupN + n([_rontgen]);
    final tanggal = _tanggal ?? (_edit ? null : DateTime.now());
    return OlDetailScaffold(
      title: title,
      foot: [OlButton(label: _edit ? 'Simpan Perubahan' : 'Simpan Pemeriksaan', loading: _busy, onPressed: _save)],
      children: [
        if (widget.prefill != null)
          const OlBanner(
            tone: OlBannerTone.info,
            icon: OlIcons.info,
            message: 'Keluhan, penyebab, lama cedera, dan keterangan rontgen diisi dari formulir pendaftaran.',
          ),
        KFormProgress(done: filled, total: 9, label: 'Isian pemeriksaan', doneLabel: 'Semua isian terisi'),
        KFormSection(
          icon: OlIcons.calendar,
          title: 'Sesi',
          subtitle: 'Kapan & oleh siapa',
          children: [
            KPickerField(
              label: 'Tanggal Pemeriksaan',
              value: tanggal == null ? null : tgl(tanggal),
              placeholder: '-',
              trailing: tanggal == null ? null : relatif(tanggal),
              onTap: _pickTanggal,
              error: _errors['tgl_periksa'],
            ),
            field('Terapis', _terapis, 'terapis', lines: 1, icon: OlIcons.user),
          ],
        ),
        KFormSection(
          icon: OlIcons.pain,
          title: 'Keluhan',
          subtitle: 'Apa yang dirasakan pasien',
          done: keluhanN,
          total: 3,
          children: [
            field('Keluhan', _keluhan, 'keluhan', lines: 3, hint: 'Mis. nyeri punggung bawah saat bangun tidur'),
            field('Penyebab Cedera', _penyebab, 'penyebab'),
            field('Lama Cedera', _lama, 'lama_cedera', lines: 1, icon: OlIcons.clock, hint: 'Mis. 2 minggu'),
          ],
        ),
        KFormSection(
          icon: OlIcons.hands,
          title: 'Pemeriksaan & Penanganan',
          subtitle: 'Diagnosa dan tindakan terapis',
          done: tanganN,
          total: 3,
          children: [
            field('Analisa dan Diagnosa', _analisa, 'analisa', lines: 3),
            field('Treatment', _treatment, 'treatment'),
            field('Bagian yang Diberikan Penanganan', _bagian, 'bagian_penenang', icon: OlIcons.body),
          ],
        ),
        KFormSection(
          icon: OlIcons.checkCircle,
          title: 'Kesimpulan',
          subtitle: 'Rekomendasi untuk pasien',
          done: n([_kesimpulan]),
          total: 1,
          children: [field('Kesimpulan dan Rekomendasi', _kesimpulan, 'kesimpulan', lines: 3)],
        ),
        KFormSection(
          icon: OlIcons.xray,
          title: 'Rontgen / MRI',
          subtitle: 'Keterangan & foto (opsional)',
          children: [
            field('Keterangan', _rontgen, 'hasil_rontgen', lines: 2, hint: 'Keterangan hasil rontgen / MRI'),
            if (_pasienId != null) IntakeXray.pasien(pasienId: _pasienId!, editable: true),
          ],
        ),
      ],
    );
  }
}
