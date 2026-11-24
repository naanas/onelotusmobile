import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import 'klinik_api.dart';
import 'klinik_models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'widgets.dart';

/// Tambah Pasien / Edit Pasien (Laravel pasien.tambah & pasien.edit).
/// Tambah: nomor boleh kosong (otomatis nomor terbesar + 1), lalu langsung ke Tambah Pemeriksaan.
/// Edit: nomor wajib. Terapis tidak melihat nomor HP; kosong = nomor HP lama dipertahankan.
class PasienFormPage extends ConsumerStatefulWidget {
  const PasienFormPage({super.key, this.editId});
  final String? editId;

  @override
  ConsumerState<PasienFormPage> createState() => _PasienFormPageState();
}

class _PasienFormPageState extends ConsumerState<PasienFormPage> {
  final _nomor = TextEditingController();
  final _nama = TextEditingController();
  final _tlp = TextEditingController();
  final _alamat = TextEditingController();
  final _instansi = TextEditingController();
  final _hobi = TextEditingController();
  final _tb = TextEditingController();
  final _bb = TextEditingController();
  DateTime? _ttl;
  String? _gender;
  Map<String, String> _errors = {};
  bool _busy = false;
  bool _loading = false;
  AppError? _loadError;

  bool get _edit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (_edit) _loadPasien();
  }

  @override
  void dispose() {
    for (final c in [
      _nomor,
      _nama,
      _tlp,
      _alamat,
      _instansi,
      _hobi,
      _tb,
      _bb,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPasien() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final p =
          (await ref.read(klinikApiProvider).detail(widget.editId!)).pasien;
      if (!mounted) return;
      _nomor.text = p.nomor?.toString() ?? '';
      _nama.text = p.nama;
      _tlp.text = p.tlp ?? '';
      _alamat.text = p.alamat ?? '';
      _instansi.text = p.instansi ?? '';
      _hobi.text = p.hobi ?? '';
      _tb.text = p.tb == null ? '' : fmtNum(p.tb!);
      _bb.text = p.bb == null ? '' : fmtNum(p.bb!);
      setState(() {
        _ttl = p.ttl;
        _gender = genderCode(p.gender);
      });
    } on AppError catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickTtl() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _ttl ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Tanggal lahir',
    );
    if (picked != null) {
      setState(() {
        _ttl = picked;
        _errors.remove('ttl');
      });
    }
  }

  Map<String, String> _validate(bool admin) {
    final e = <String, String>{};
    if (_nama.text.trim().isEmpty) e['nama'] = 'Nama wajib diisi.';
    if (_ttl == null) e['ttl'] = 'Tanggal lahir wajib diisi.';
    final tlp = _tlp.text.replaceAll(RegExp(r'[\s-]'), '');
    if (tlp.isEmpty && (!_edit || admin)) {
      e['tlp'] = 'Nomor telepon wajib diisi.';
    } else if (tlp.isNotEmpty && !RegExp(r'^\d+$').hasMatch(tlp)) {
      e['tlp'] = 'Nomor telepon harus berupa angka.';
    }
    if (_alamat.text.trim().isEmpty) e['alamat'] = 'Alamat wajib diisi.';
    if (_gender == null) e['gender'] = 'Pilih jenis kelamin.';
    if (_instansi.text.trim().isEmpty) {
      e['instansi'] = 'Instansi wajib diisi (isi "-" bila tidak ada).';
    }
    if (_edit && _nomor.text.trim().isEmpty) {
      e['nomor'] = 'Nomor pasien wajib diisi.';
    }
    if (_nomor.text.trim().isNotEmpty &&
        int.tryParse(_nomor.text.trim()) == null) {
      e['nomor'] = 'Nomor pasien harus berupa angka.';
    }
    for (final (k, c) in [('bb', _bb), ('tb', _tb)]) {
      if (c.text.trim().isNotEmpty &&
          num.tryParse(c.text.trim().replaceAll(',', '.')) == null) {
        e[k] = 'Harus berupa angka.';
      }
    }
    return e;
  }

  Future<void> _save() async {
    final admin = (ref.read(authProvider).user?.isAdmin ?? false);
    final errs = _validate(admin);
    setState(() => _errors = errs);
    if (errs.isNotEmpty) {
      context.feedback.info('Periksa kembali isian yang ditandai.');
      return;
    }
    final body = <String, dynamic>{
      'nomor': _nomor.text.trim().isEmpty ? null : _nomor.text.trim(),
      'nama': _nama.text.trim(),
      'ttl': ymd(_ttl!),
      'tlp': _tlp.text.trim().isEmpty ? null : _tlp.text.trim(),
      'alamat': _alamat.text.trim(),
      'gender': _gender,
      'instansi': _instansi.text.trim(),
      'hobi': _hobi.text.trim(),
      'tb': _tb.text.trim(),
      'bb': _bb.text.trim(),
    };
    setState(() => _busy = true);
    final api = ref.read(klinikApiProvider);
    try {
      if (_edit) {
        await api.editPasien(widget.editId!, body);
        if (!mounted) return;
        context.feedback.success('Data pasien berhasil diedit.');
        context.pop(true);
      } else {
        final p = await api.tambahPasien(body);
        if (!mounted) return;
        context.feedback.success('Data pasien berhasil dibuat.');
        // Laravel: setelah tambah pasien langsung ke tambah pemeriksaan.
        context.pushReplacement(
          Routes.klinikTambahPemeriksaan(p.id, lanjutDetail: true),
        );
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

  void _clear(String k) {
    if (_errors.containsKey(k)) setState(() => _errors.remove(k));
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authProvider.select((s) => s.user?.isAdmin ?? false));
    final showTlp = !_edit || admin;
    final c = context.ol;
    final t = context.olText;
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))];
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    if (_loading || _loadError != null) {
      return OlDetailScaffold(
        title: 'Edit Pasien',
        children: [
          if (_loadError != null)
            OlErrorCard(message: _loadError!.message, onRetry: _loadPasien)
          else
            const OlLoadingCard(),
        ],
      );
    }

    return OlDetailScaffold(
      title: _edit ? 'Edit Pasien' : 'Tambah Pasien',
      foot: [OlButton(label: 'Simpan', loading: _busy, onPressed: _save)],
      children: [
        OlTextField(
          label: 'Nomor',
          isRequired: _edit,
          controller: _nomor,
          keyboardType: TextInputType.number,
          inputFormatters: digits,
          helper: _edit ? null : 'Kosongkan untuk nomor otomatis.',
          error: _errors['nomor'],
          onChanged: (_) => _clear('nomor'),
        ),
        OlTextField(
          label: 'Nama',
          isRequired: true,
          controller: _nama,
          error: _errors['nama'],
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clear('nama'),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tanggal Lahir *', style: t.fieldLabel),
            const SizedBox(height: 6),
            OlCard(
              onTap: _pickTtl,
              semanticLabel: 'Pilih tanggal lahir',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _ttl == null ? 'Pilih tanggal' : tgl(_ttl),
                      style: t.body.copyWith(
                        color: _ttl == null ? c.faint : c.fg,
                      ),
                    ),
                  ),
                  OlIcon(OlIcons.calendar, color: c.brand),
                ],
              ),
            ),
            if (_errors['ttl'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _errors['ttl']!,
                  style: t.caption.copyWith(color: c.crit),
                ),
              ),
          ],
        ),
        if (showTlp)
          OlTextField(
            label: 'Nomor Telepon',
            isRequired: true,
            controller: _tlp,
            keyboardType: TextInputType.phone,
            inputFormatters: digits,
            error: _errors['tlp'],
            onChanged: (_) => _clear('tlp'),
          )
        else
          const OlBanner(
            tone: OlBannerTone.info,
            icon: OlIcons.lock,
            message: 'Nomor telepon hanya bisa dilihat dan diubah admin.',
          ),
        OlTextField(
          label: 'Alamat',
          isRequired: true,
          controller: _alamat,
          maxLines: 2,
          error: _errors['alamat'],
          onChanged: (_) => _clear('alamat'),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Jenis Kelamin *', style: t.fieldLabel),
            const SizedBox(height: 6),
            OlRadioList<String>(
              options: const [
                OlRadioOption(value: 'L', title: 'Laki - Laki'),
                OlRadioOption(value: 'P', title: 'Perempuan'),
              ],
              value: _gender,
              onChanged: (v) => setState(() {
                _gender = v;
                _errors.remove('gender');
              }),
            ),
            if (_errors['gender'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _errors['gender']!,
                  style: t.caption.copyWith(color: c.crit),
                ),
              ),
          ],
        ),
        OlTextField(
          label: 'Instansi',
          isRequired: true,
          controller: _instansi,
          error: _errors['instansi'],
          onChanged: (_) => _clear('instansi'),
        ),
        OlTextField(
          label: 'Hobi / Kegiatan',
          controller: _hobi,
          error: _errors['hobi'],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OlTextField(
                label: 'Berat Badan',
                controller: _bb,
                suffixText: 'kg',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: decimal,
                error: _errors['bb'],
                onChanged: (_) => _clear('bb'),
              ),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: OlTextField(
                label: 'Tinggi Badan',
                controller: _tb,
                suffixText: 'cm',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: decimal,
                error: _errors['tb'],
                onChanged: (_) => _clear('tb'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
