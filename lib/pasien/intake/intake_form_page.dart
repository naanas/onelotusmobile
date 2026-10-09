import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../data/intake/intake_form_repository.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../data/sync/outbox.dart' show newId;
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// WB-01 Formulir pasien baru (di aplikasi, tanpa login). Dibuka dari QR KS-02 — lewat kamera HP
/// (tautan `onelotus://app/intake/{kode}`) atau pemindai di layar masuk. Aturan isian = KS-04 + keluhan.
/// Draf tersimpan otomatis di HP; foto rontgen opsional (maks 3) diperkecil sebelum dikirim.
class IntakeFormPage extends ConsumerStatefulWidget {
  const IntakeFormPage({super.key, required this.code});

  final String code;

  @override
  ConsumerState<IntakeFormPage> createState() => _IntakeFormPageState();
}

class _IntakeFormPageState extends ConsumerState<IntakeFormPage> {
  static const maxPhotos = 3;

  final _name = TextEditingController();
  final _place = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _job = TextEditingController();
  final _hobby = TextEditingController();
  final _tb = TextEditingController();
  final _bb = TextEditingController();
  final _complaint = TextEditingController();
  final _duration = TextEditingController();
  late String _clientId = newId();
  DateTime? _birth;
  Gender? _gender;
  IntakeCause? _cause;
  String _unit = 'week';
  bool _consent = false;
  final List<Uint8List> _photos = [];

  String? _branch;
  AppError? _loadError;
  bool _busy = false;
  bool _showAll = false;
  Map<String, String> _serverErrors = const {};
  IntakeReceipt? _receipt;
  Timer? _saveTimer;

  String get _draftKey => 'intake:${widget.code}';

  List<TextEditingController> get _texts => [
    _name,
    _place,
    _phone,
    _address,
    _job,
    _hobby,
    _tb,
    _bb,
    _complaint,
    _duration,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final c in _texts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    await _restoreDraft();
    try {
      final name = await ref
          .read(intakeFormRepositoryProvider)
          .branchName(widget.code);
      if (mounted) setState(() => _branch = name);
    } on AppError catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  // ── Draf di HP (A.0: layar yang menulis data menyimpan draf lokal) ──────

  Future<void> _restoreDraft() async {
    try {
      final saved = await ref.read(draftStoreProvider).get(_draftKey);
      final m = saved?.json;
      if (m is! Map || !mounted) return;
      setState(() {
        _clientId = m['client_id'] as String? ?? _clientId;
        _name.text = m['name'] as String? ?? '';
        _place.text = m['birth_place'] as String? ?? '';
        _phone.text = m['phone'] as String? ?? '';
        _address.text = m['address'] as String? ?? '';
        _job.text = m['institution'] as String? ?? '';
        _hobby.text = m['hobby'] as String? ?? '';
        _tb.text = m['height'] as String? ?? '';
        _bb.text = m['weight'] as String? ?? '';
        _complaint.text = m['complaint'] as String? ?? '';
        _duration.text = m['duration'] as String? ?? '';
        _birth = DateTime.tryParse(m['birth_date'] as String? ?? '');
        _gender = Gender.fromApi(m['gender']);
        _cause = IntakeCause.fromApi(m['cause']);
        _unit = m['unit'] as String? ?? 'week';
        _consent = m['consent'] as bool? ?? false;
      });
    } catch (_) {
      // Draf tidak terbaca: mulai dari form kosong.
    }
  }

  void _changed() {
    setState(() => _serverErrors = const {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveDraft);
  }

  Future<void> _saveDraft() async {
    try {
      await ref.read(draftStoreProvider).put(_draftKey, {
        'client_id': _clientId,
        'name': _name.text,
        'birth_place': _place.text,
        'phone': _phone.text,
        'address': _address.text,
        'institution': _job.text,
        'hobby': _hobby.text,
        'height': _tb.text,
        'weight': _bb.text,
        'complaint': _complaint.text,
        'duration': _duration.text,
        'birth_date': _birth == null ? null : formatDayIso(_birth!),
        'gender': _gender?.api,
        'cause': _cause?.api,
        'unit': _unit,
        'consent': _consent,
      });
    } catch (_) {
      // Penyimpanan HP penuh/gagal: form tetap bisa dikirim.
    }
  }

  Future<void> _clearDraft() async {
    try {
      await ref.read(draftStoreProvider).delete(_draftKey);
    } catch (_) {}
  }

  // ── Validasi (sama dengan server) ──────────────────────────────────────

  static final _nameRe = RegExp(r"^\p{L}[\p{L} .,'-]*$", unicode: true);
  static final _phoneRe = RegExp(r'^(\+?62|0)8\d+$');

  Map<String, String> get _clientErrors {
    final e = <String, String>{};
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2 || name.length > 100 || !_nameRe.hasMatch(name)) {
      e['name'] = 'Isi nama lengkap (2–100 huruf).';
    }
    if (_birth == null) e['birth_date'] = 'Isi tanggal lahir.';
    if (_gender == null) e['gender'] = 'Pilih jenis kelamin.';
    final compact = _phone.text.replaceAll(RegExp(r'[\s-]'), '');
    final digits = compact.replaceFirst('+', '');
    if (!_phoneRe.hasMatch(compact) ||
        digits.length < 10 ||
        digits.length > 14) {
      e['phone'] = 'Nomor HP tidak valid, mis. 0812 3456 7890.';
    }
    int? n(TextEditingController c) =>
        c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());
    final tb = n(_tb), bb = n(_bb);
    if (_tb.text.trim().isNotEmpty && (tb == null || tb < 50 || tb > 250)) {
      e['height_cm'] = 'Isi dengan angka, mis. 162';
    }
    if (_bb.text.trim().isNotEmpty && (bb == null || bb < 2 || bb > 300)) {
      e['weight_kg'] = 'Isi dengan angka, mis. 55';
    }
    if (_complaint.text.trim().isEmpty) {
      e['complaint'] = 'Ceritakan singkat apa yang Anda rasakan.';
    }
    if (_duration.text.trim().isNotEmpty && n(_duration) == null) {
      e['injury_duration'] = 'Isi dengan angka, mis. 2';
    }
    if (!_consent) {
      e['health_consent'] = 'Centang persetujuan data untuk melanjutkan.';
    }
    return e;
  }

  String? _err(String field) =>
      _serverErrors[field] ?? (_showAll ? _clientErrors[field] : null);

  int get _visibleErrorCount => _showAll
      ? {
          ..._clientErrors.keys,
          ..._serverErrors.keys,
        }.where((k) => k != 'photos' && k != 'form').length
      : 0;

  // ── Aksi ───────────────────────────────────────────────────────────────

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('id'),
      helpText: 'Tanggal lahir',
    );
    if (picked == null) return;
    setState(() => _birth = picked);
    _changed();
  }

  Future<void> _addPhoto() async {
    final source = await context.feedback.sheet<ImageSource>(
      title: 'Tambah foto rontgen',
      actions: const [
        SheetAction('Ambil foto', ImageSource.camera),
        SheetAction(
          'Pilih dari galeri',
          ImageSource.gallery,
          variant: OlButtonVariant.secondary,
        ),
      ],
    );
    if (source == null) return;
    try {
      // Sisi terpanjang 1600 px, JPEG 80%: rontgen tetap terbaca, unggah cepat.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (_photos.length < maxPhotos) _photos.add(bytes);
        _serverErrors = const {};
      });
    } on PlatformException {
      if (mounted) context.feedback.error(const AppError(ErrorCode.permCamera));
    }
  }

  Future<void> _submit() async {
    setState(() => _showAll = true);
    if (_clientErrors.isNotEmpty) {
      context.feedback.info(
        'Perbaiki ${_clientErrors.length} isian yang ditandai merah.',
      );
      return;
    }
    setState(() => _busy = true);
    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      final receipt = await ref
          .read(intakeFormRepositoryProvider)
          .submit(
            widget.code,
            IntakeSubmission(
              clientId: _clientId,
              name: _name.text.trim(),
              birthDate: _birth!,
              gender: _gender!,
              phone: _phone.text.trim(),
              complaint: _complaint.text.trim(),
              healthConsent: _consent,
              birthPlace: opt(_place),
              address: opt(_address),
              institution: opt(_job),
              hobby: opt(_hobby),
              heightCm: int.tryParse(_tb.text.trim()),
              weightKg: int.tryParse(_bb.text.trim()),
              cause: _cause,
              injuryDuration: int.tryParse(_duration.text.trim()),
              injuryDurationUnit: _unit,
              photos: _photos,
            ),
          );
      await _clearDraft();
      if (mounted) setState(() => _receipt = receipt);
    } on AppError catch (e) {
      if (!mounted) return;
      if (e.type == ErrorCode.validation && e.fieldErrors.isNotEmpty) {
        setState(
          () => _serverErrors = {
            for (final f in e.fieldErrors.entries)
              if (f.value.isNotEmpty) f.key: f.value.first,
          },
        );
        context.feedback.info('Periksa lagi isian yang ditandai merah.');
      } else {
        // Isian tetap aman di HP; pasien bisa coba kirim lagi.
        context.feedback.error(e, retry: _submit);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Tampilan ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    if (receipt != null) return IntakeThanksView(receipt: receipt);

    final err = _loadError;
    if (err != null) {
      final expired = err.type == ErrorCode.notFound;
      return OlMessageScreen(
        illustration: expired
            ? OlIllustration.emptySearch
            : OlIllustration.serverError,
        title: expired
            ? 'Kode QR sudah tidak berlaku'
            : 'Formulir belum bisa dibuka',
        message: expired
            ? 'Minta QR terbaru ke front desk, lalu pindai lagi.'
            : 'Periksa koneksi internet Anda, lalu coba lagi.',
        foot: [
          if (!expired) OlButton(label: 'Coba lagi', onPressed: _load),
          OlButton(
            label: 'Kembali',
            variant: OlButtonVariant.secondary,
            onPressed: _leave,
          ),
        ],
      );
    }

    final c = context.ol;
    final t = context.olText;
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: OlSpace.md),
        Expanded(child: b),
      ],
    );
    void onText(String _) => _changed();
    final digitsOnly = [FilteringTextInputFormatter.digitsOnly];
    final errorCount = _visibleErrorCount;

    return Scaffold(
      backgroundColor: c.bg,
      bottomNavigationBar: OlFootBar(
        children: [
          OlButton(
            label: 'Kirim formulir',
            loading: _busy,
            onPressed: _branch == null || _busy ? null : _submit,
          ),
          if (errorCount > 0)
            Text(
              'Perbaiki $errorCount isian yang ditandai merah',
              textAlign: TextAlign.center,
              style: t.caption,
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(branch: _branch, onClose: _leave),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList.list(
              children: [
                for (final w in <Widget>[
                  const OlOverline('Data diri'),
                  OlTextField(
                    label: 'Nama lengkap',
                    isRequired: true,
                    controller: _name,
                    error: _err('name'),
                    autofillHints: const [AutofillHints.name],
                    onChanged: onText,
                  ),
                  pair(
                    _DateField(
                      value: _birth,
                      error: _err('birth_date'),
                      onTap: _pickBirth,
                    ),
                    OlTextField(
                      label: 'Tempat lahir',
                      controller: _place,
                      onChanged: onText,
                    ),
                  ),
                  _Labeled(
                    label: 'Jenis kelamin',
                    required: true,
                    error: _err('gender'),
                    child: OlSegmented<Gender?>(
                      segments: {for (final g in Gender.values) g: g.label},
                      value: _gender,
                      onChanged: (v) {
                        setState(() => _gender = v);
                        _changed();
                      },
                    ),
                  ),
                  OlTextField(
                    label: 'Nomor HP (WhatsApp)',
                    isRequired: true,
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    error: _err('phone'),
                    autofillHints: const [AutofillHints.telephoneNumber],
                    onChanged: onText,
                  ),
                  OlTextField(
                    label: 'Alamat',
                    controller: _address,
                    onChanged: onText,
                  ),
                  pair(
                    OlTextField(
                      label: 'Pekerjaan / instansi',
                      controller: _job,
                      onChanged: onText,
                    ),
                    OlTextField(
                      label: 'Hobi / olahraga',
                      controller: _hobby,
                      onChanged: onText,
                    ),
                  ),
                  pair(
                    OlTextField(
                      label: 'Tinggi badan',
                      controller: _tb,
                      suffixText: 'cm',
                      keyboardType: TextInputType.number,
                      inputFormatters: digitsOnly,
                      error: _err('height_cm'),
                      onChanged: onText,
                    ),
                    OlTextField(
                      label: 'Berat badan',
                      controller: _bb,
                      suffixText: 'kg',
                      keyboardType: TextInputType.number,
                      inputFormatters: digitsOnly,
                      error: _err('weight_kg'),
                      onChanged: onText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const OlOverline('Keluhan'),
                  OlTextField(
                    label: 'Apa yang Anda rasakan?',
                    isRequired: true,
                    controller: _complaint,
                    maxLines: 3,
                    hint:
                        'mis. Nyeri pinggang bawah, makin terasa setelah duduk lama.',
                    error: _err('complaint'),
                    onChanged: onText,
                  ),
                  _Labeled(
                    label: 'Penyebab',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cause in IntakeCause.values)
                          OlChip(
                            label: cause.label,
                            selected: _cause == cause,
                            onTap: () {
                              setState(
                                () => _cause = _cause == cause ? null : cause,
                              );
                              _changed();
                            },
                          ),
                      ],
                    ),
                  ),
                  _Labeled(
                    label: 'Sudah berapa lama?',
                    error: _err('injury_duration'),
                    child: pair(
                      OlTextField(
                        label: 'Lama keluhan',
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        inputFormatters: digitsOnly,
                        hint: 'mis. 2',
                        onChanged: onText,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 26),
                        child: OlSegmented<String>(
                          segments: const {
                            'day': 'Hari',
                            'week': 'Minggu',
                            'month': 'Bulan',
                          },
                          value: _unit,
                          onChanged: (v) {
                            setState(() => _unit = v);
                            _changed();
                          },
                        ),
                      ),
                    ),
                  ),
                  _Labeled(
                    label: 'Foto rontgen (opsional, maks 3)',
                    error: _serverErrors['photos'],
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final (i, p) in _photos.indexed)
                          _PhotoThumb(
                            bytes: p,
                            index: i,
                            onRemove: () => setState(() => _photos.removeAt(i)),
                          ),
                        if (_photos.length < maxPhotos)
                          _AddPhoto(onTap: _addPhoto),
                      ],
                    ),
                  ),
                  _ConsentCard(
                    value: _consent,
                    error: _err('health_consent'),
                    onChanged: (v) {
                      setState(() => _consent = v);
                      _changed();
                    },
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: OlSpace.lg),
                    child: w,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.login);
    }
  }
}

String formatDayIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Layar "Terima kasih" + nomor antrian (WB-01b).
class IntakeThanksView extends StatelessWidget {
  const IntakeThanksView({super.key, required this.receipt});

  final IntakeReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.login);
      },
      child: OlMessageScreen(
        illustration: OlIllustration.thanksIntake,
        title: 'Terima kasih, ${receipt.firstName}',
        message:
            'Formulir sudah diterima. Silakan duduk, kami akan memanggil Anda.',
        foot: [
          OlButton(
            label: 'Selesai',
            variant: OlButtonVariant.secondary,
            onPressed: () => context.go(Routes.login),
          ),
        ],
        children: [
          const SizedBox(height: 20),
          Semantics(
            label: 'Nomor antrian ${receipt.queueLabel}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6F9),
                borderRadius: BorderRadius.circular(22),
                boxShadow: OlShadow.sh1,
              ),
              child: Column(
                children: [
                  Text(
                    'NOMOR ANTRIAN',
                    style: t.overline.copyWith(color: c.faint),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    receipt.queueLabel,
                    style: t.mono.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: c.brandDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nomor pasien Anda akan dikirim lewat WhatsApp setelah diverifikasi front desk.',
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.branch, required this.onClose});

  final String? branch;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: const Color(0xFF0C4A6E),
      padding: EdgeInsets.fromLTRB(20, top + 14, 12, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const OlLogoMark(size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'One Lotus',
                      style: t.bodyStrong.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Formulir pasien baru',
                  style: t.display.copyWith(color: Colors.white, fontSize: 26),
                ),
                const SizedBox(height: 6),
                branch == null
                    ? const Skeleton(width: 220, height: 14)
                    : Text(
                        '$branch · ±3 menit · data tersimpan otomatis di HP ini',
                        style: t.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tutup',
            onPressed: onClose,
            icon: const OlIcon(OlIcons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.label,
    required this.child,
    this.required = false,
    this.error,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: c.crit),
                ),
            ],
          ),
          style: t.fieldLabel,
        ),
        const SizedBox(height: 8),
        child,
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: t.caption.copyWith(
              color: c.crit,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap, this.error});

  final DateTime? value;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return _Labeled(
      label: 'Tanggal lahir',
      required: true,
      error: error,
      child: Semantics(
        button: true,
        label: 'Tanggal lahir',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: error != null ? c.crit : c.line,
                width: 1.5,
              ),
            ),
            child: Text(
              value == null ? 'Pilih tanggal' : Fmt.dateNoDay(value!),
              style: t.body.copyWith(
                fontSize: 15,
                color: value == null ? c.faint : c.fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.bytes,
    required this.index,
    required this.onRemove,
  });

  final Uint8List bytes;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    height: 84,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            semanticLabel: 'Foto rontgen ${index + 1}',
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton.filled(
            tooltip: 'Hapus foto ${index + 1}',
            onPressed: onRemove,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              minimumSize: const Size(28, 28),
              padding: EdgeInsets.zero,
            ),
            icon: const OlIcon(OlIcons.close, size: 16, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class _AddPhoto extends StatelessWidget {
  const _AddPhoto({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Semantics(
      button: true,
      label: 'Tambah foto rontgen',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: Center(child: OlIcon(OlIcons.camera, color: c.muted)),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.value,
    required this.onChanged,
    this.error,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OlCheckbox(
            label:
                'Saya menyetujui penggunaan data kesehatan untuk keperluan terapi *',
            value: value,
            onChanged: onChanged,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.feedback.sheet<void>(
                title: 'Kebijakan privasi One Lotus',
                message:
                    'Data identitas dan kesehatan Anda hanya dipakai untuk layanan terapi di One Lotus, sesuai UU Pelindungan Data Pribadi No. 27/2022. Data tidak dibagikan ke pihak lain tanpa izin Anda. Anda dapat meminta salinan, perbaikan, atau penghapusan data melalui front desk.',
                actions: const [
                  SheetAction(
                    'Tutup',
                    null,
                    variant: OlButtonVariant.secondary,
                  ),
                ],
              ),
              style: TextButton.styleFrom(
                foregroundColor: c.brand,
                textStyle: t.bodyStrong,
              ),
              child: const Text('Baca kebijakan privasi'),
            ),
          ),
          if (error != null)
            Text(
              error!,
              style: t.caption.copyWith(
                color: c.crit,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
