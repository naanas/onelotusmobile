import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import 'k_ui.dart';
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

  final _secIdentitas = GlobalKey();
  final _secKontak = GlobalKey();
  final _secLainnya = GlobalKey();

  List<TextEditingController> get _ctls => [_nomor, _nama, _tlp, _alamat, _instansi, _hobi, _tb, _bb];

  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    for (final c in _ctls) {
      c.addListener(_changed);
    }
    if (_edit) _loadPasien();
  }

  /// Gulir ke seksi pertama yang punya isian salah.
  void _scrollToError(Map<String, String> e) {
    final key = e.keys.any((k) => const {'nomor', 'nama', 'ttl', 'gender'}.contains(k))
        ? _secIdentitas
        : e.keys.any((k) => const {'tlp', 'alamat'}.contains(k))
        ? _secKontak
        : _secLainnya;
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: OlMotion.of(context, const Duration(milliseconds: 360)),
        curve: OlMotion.curve,
        alignment: .05,
      );
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

  Future<void> _loadPasien() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final p = (await ref.read(klinikApiProvider).detail(widget.editId!)).pasien;
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
    if (_nomor.text.trim().isNotEmpty && int.tryParse(_nomor.text.trim()) == null) {
      e['nomor'] = 'Nomor pasien harus berupa angka.';
    }
    for (final (k, c) in [('bb', _bb), ('tb', _tb)]) {
      if (c.text.trim().isNotEmpty && num.tryParse(c.text.trim().replaceAll(',', '.')) == null) {
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
      HapticFeedback.mediumImpact();
      _scrollToError(errs);
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
        context.pushReplacement(Routes.klinikTambahPemeriksaan(p.id, lanjutDetail: true));
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

    bool f(TextEditingController c) => c.text.trim().isNotEmpty;
    final idDone = [if (_edit) f(_nomor), f(_nama), _ttl != null, _gender != null].where((x) => x).length;
    final idTotal = _edit ? 4 : 3;
    final kontakDone = [if (showTlp) f(_tlp), f(_alamat)].where((x) => x).length;
    final kontakTotal = showTlp ? 2 : 1;
    final lainDone = f(_instansi) ? 1 : 0;
    final u = umur(_ttl);

    return OlDetailScaffold(
      title: _edit ? 'Edit Pasien' : 'Tambah Pasien',
      foot: [
        OlButton(label: _edit ? 'Simpan Perubahan' : 'Simpan & Lanjut Pemeriksaan', loading: _busy, onPressed: _save),
      ],
      children: [
        Text(
          _edit
              ? 'Perbarui data pasien. Isian bertanda * wajib diisi.'
              : 'Isi data pasien baru. Setelah disimpan langsung lanjut ke pemeriksaan.',
          style: t.body.copyWith(color: c.muted),
        ),
        KFormProgress(
          done: idDone + kontakDone + lainDone,
          total: idTotal + kontakTotal + 1,
          label: 'Kelengkapan data wajib',
          doneLabel: 'Data wajib lengkap · siap disimpan',
        ),
        KFormSection(
          key: _secIdentitas,
          icon: OlIcons.user,
          title: 'Identitas',
          subtitle: 'Nama, tanggal lahir, jenis kelamin',
          done: idDone,
          total: idTotal,
          children: [
            OlTextField(
              label: 'Nomor Pasien',
              icon: OlIcons.receipt,
              isRequired: _edit,
              controller: _nomor,
              mono: true,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              hint: _edit ? null : 'Otomatis',
              helper: _edit ? null : 'Kosongkan untuk nomor otomatis (nomor terbesar + 1).',
              error: _errors['nomor'],
              onChanged: (_) => _clear('nomor'),
            ),
            OlTextField(
              label: 'Nama Lengkap',
              icon: OlIcons.user,
              isRequired: true,
              controller: _nama,
              error: _errors['nama'],
              textInputAction: TextInputAction.next,
              onChanged: (_) => _clear('nama'),
            ),
            KPickerField(
              label: 'Tanggal Lahir',
              required: true,
              value: _ttl == null ? null : tgl(_ttl),
              placeholder: 'Pilih tanggal lahir',
              trailing: u == null ? null : '$u tahun',
              onTap: _pickTtl,
              error: _errors['ttl'],
            ),
            KChoice<String>(
              label: 'Jenis Kelamin',
              required: true,
              options: const [('L', 'Laki-laki', null), ('P', 'Perempuan', null)],
              value: _gender,
              error: _errors['gender'],
              onChanged: (v) => setState(() {
                _gender = v;
                _errors.remove('gender');
              }),
            ),
          ],
        ),
        KFormSection(
          key: _secKontak,
          icon: OlIcons.phone,
          title: 'Kontak & Alamat',
          subtitle: showTlp ? 'Nomor telepon hanya terlihat oleh admin' : null,
          done: kontakDone,
          total: kontakTotal,
          children: [
            if (showTlp)
              OlTextField(
                label: 'Nomor Telepon',
                icon: OlIcons.phone,
                isRequired: true,
                controller: _tlp,
                mono: true,
                hint: '08xxxxxxxxxx',
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
              icon: OlIcons.pin,
              isRequired: true,
              controller: _alamat,
              maxLines: 2,
              error: _errors['alamat'],
              onChanged: (_) => _clear('alamat'),
            ),
          ],
        ),
        KFormSection(
          key: _secLainnya,
          icon: OlIcons.body,
          title: 'Data Tambahan',
          subtitle: 'Instansi, kegiatan, dan postur tubuh',
          done: lainDone,
          total: 1,
          children: [
            OlTextField(
              label: 'Instansi',
              icon: OlIcons.branch,
              isRequired: true,
              controller: _instansi,
              hint: 'Isi "-" bila tidak ada',
              error: _errors['instansi'],
              onChanged: (_) => _clear('instansi'),
            ),
            OlTextField(label: 'Hobi / Kegiatan', icon: OlIcons.exercise, controller: _hobi, error: _errors['hobi']),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OlTextField(
                    label: 'Berat Badan',
                    controller: _bb,
                    mono: true,
                    suffixText: 'kg',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    mono: true,
                    suffixText: 'cm',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimal,
                    error: _errors['tb'],
                    onChanged: (_) => _clear('tb'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
