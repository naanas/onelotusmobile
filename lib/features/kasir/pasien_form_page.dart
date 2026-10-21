import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/api_error_mapper.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-04 Tambah / ubah data pasien. Nomor pasien dibuat server, cek ganda (ST-08) dari server.
/// Persetujuan PDP wajib untuk pasien baru (§5.11).
class PasienFormPage extends ConsumerStatefulWidget {
  const PasienFormPage({super.key, this.patientId});

  /// Ubah data pasien yang sudah ada (KS-04 edit).
  final String? patientId;

  @override
  ConsumerState<PasienFormPage> createState() => _PasienFormPageState();
}

class _PasienFormPageState extends ConsumerState<PasienFormPage> {
  final _name = TextEditingController();
  final _place = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _tb = TextEditingController();
  final _bb = TextEditingController();
  final _job = TextEditingController();
  final _hobby = TextEditingController();
  final _complaint = TextEditingController();
  DateTime? _birth;
  Gender _gender = Gender.female;
  bool _consent = false;
  bool _busy = false;

  AppError? _loadError;
  Map<String, List<String>> _fieldErrors = const {};

  Patient? _editing;

  bool get _editMode => widget.patientId != null;

  @override
  void initState() {
    super.initState();
    if (_editMode) _loadPatient();
  }

  Future<void> _loadPatient() async {
    setState(() => _loadError = null);
    try {
      final p = await ref.read(oneLotusApiProvider).patient(widget.patientId!);
      if (!mounted) return;
      setState(() {
        _editing = p;
        _name.text = p.name;
        _birth = p.birthDate;
        _place.text = p.birthPlace ?? '';
        _gender = p.gender ?? Gender.female;
        _phone.text = p.phone ?? '';
        _address.text = p.address == '-' ? '' : (p.address ?? '');
        _tb.text = p.heightCm?.round().toString() ?? '';
        _bb.text = p.weightKg?.round().toString() ?? '';
        _job.text = p.institution == '-' ? '' : (p.institution ?? '');
        _hobby.text = p.hobby ?? '';
        _consent = true;
      });
    } on AppError catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _place,
      _phone,
      _address,
      _tb,
      _bb,
      _job,
      _hobby,
      _complaint,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  String? _err(String field) => _fieldErrors[field]?.firstOrNull;

  String? get _phoneError =>
      _err('phone') ??
      (_digits.isNotEmpty && _digits.length < 10
          ? 'Nomor HP belum lengkap — minimal 10 digit, mis. 0812 3456 7890.'
          : null);

  bool get _valid =>
      _name.text.trim().length >= 2 &&
      _birth != null &&
      _digits.length >= 10 &&
      _consent;

  String? _opt(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  PatientDraft get _draft => PatientDraft(
    name: _name.text.trim(),
    birthDate: _birth!,
    gender: _gender,
    phone: _phone.text.trim(),
    birthPlace: _opt(_place),
    address: _opt(_address),
    institution: _opt(_job),
    hobby: _opt(_hobby),
    heightCm: int.tryParse(_tb.text),
    weightKg: int.tryParse(_bb.text),
    initialComplaint: _opt(_complaint),
    healthConsent: _consent,
  );

  Future<Patient> _send({bool confirm = false}) => _editMode
      ? ref
            .read(oneLotusApiProvider)
            .updatePatient(
              widget.patientId!,
              _draft,
              confirmNotDuplicate: confirm,
            )
      : ref
            .read(oneLotusApiProvider)
            .createPatient(_draft, confirmNotDuplicate: confirm);

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _fieldErrors = const {};
    });
    try {
      Patient patient;
      try {
        patient = await _send();
      } on DuplicatePatientError catch (dup) {
        if (!mounted) return;
        setState(() => _busy = false);
        final existing = dup.candidates.first;
        final choice = await showDuplicatePatientSheet(
          context,
          existing: PatientBrief(
            name: existing['name'] as String? ?? '-',
            number: Fmt.patientNo(parseIntOr0(existing['number'])),
            detail: duplicateDetail(existing),
          ),
          incoming: PatientBrief(
            name: _name.text.trim(),
            detail: [
              Fmt.dateNoDay(_birth!),
              'HP berakhiran ${_digits.length >= 4 ? _digits.substring(_digits.length - 4) : '–'}',
            ].join(' · '),
          ),
        );
        if (choice == null || !mounted) return;
        setState(() => _busy = true);
        if (choice == DuplicateChoice.openExisting) {
          if (_editMode) {
            context.feedback.info(
              'Perubahan dibatalkan. Data lama tidak diubah.',
            );
            Navigator.of(context).maybePop();
            return;
          }
          // Tambah manual: tidak ada yang digabung, cukup batal dan buka data lama dari daftar pasien.
          context.feedback.info(
            'Pakai data lama ${Fmt.patientNo(parseIntOr0(existing['number']))}. Cari di daftar pasien.',
          );
          Navigator.of(context).maybePop();
          return;
        } else {
          patient = await _send(confirm: true);
        }
      }
      if (!mounted) return;
      context.feedback.success(
        _editMode
            ? 'Data ${patient.name} disimpan.'
            : 'Pasien ${Fmt.patientNo(patient.number)} dibuat.',
      );
      Navigator.of(context).maybePop();
    } on AppError catch (e) {
      if (!mounted) return;
      if (e.type == ErrorCode.validation && e.fieldErrors.isNotEmpty) {
        setState(() => _fieldErrors = e.fieldErrors);
        context.feedback.error(e);
      } else {
        context.feedback.error(e, retry: _save);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
    if (picked != null) setState(() => _birth = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    if (_editMode && _editing == null) {
      return OlDetailScaffold(
        title: 'Edit data pasien',
        children: [
          if (_loadError == null)
            const OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 200, height: 18),
                  SizedBox(height: 12),
                  Skeleton(height: 14),
                  SizedBox(height: 8),
                  Skeleton(height: 14),
                ],
              ),
            )
          else
            OlCard(
              child: Column(
                children: [
                  Text(
                    _loadError!.type == ErrorCode.notFound
                        ? 'Data pasien tidak ditemukan atau sudah diarsipkan.'
                        : 'Data belum bisa dimuat. Coba beberapa saat lagi.',
                    style: t.body.copyWith(color: c.muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OlButton(
                    label: 'Coba lagi',
                    expand: false,
                    onPressed: _loadPatient,
                  ),
                ],
              ),
            ),
        ],
      );
    }

    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: OlSpace.md),
        Expanded(child: b),
      ],
    );
    void touch(String _) => setState(() {});

    return OlDetailScaffold(
      title: _editMode ? 'Edit data pasien' : 'Tambah pasien',
      foot: [
        OlButton(
          label: _editMode ? 'Simpan perubahan' : 'Simpan & buat nomor pasien',
          loading: _busy,
          onPressed: _valid && !_busy ? _save : null,
        ),
      ],
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Nomor pasien',
                  style: t.body.copyWith(color: c.muted),
                ),
              ),
              Text(
                _editing != null
                    ? Fmt.patientNo(_editing!.number)
                    : 'Otomatis saat disimpan',
                style: t.mono.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const OlOverline('Identitas'),
        OlTextField(
          label: 'Nama lengkap',
          isRequired: true,
          controller: _name,
          error: _err('name'),
          onChanged: touch,
        ),
        pair(
          _BirthField(
            value: _birth,
            error: _err('birth_date'),
            onTap: _pickBirth,
          ),
          OlTextField(label: 'Tempat lahir', controller: _place),
        ),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Jenis kelamin'),
              TextSpan(
                text: ' *',
                style: TextStyle(color: c.crit),
              ),
            ],
          ),
          style: t.fieldLabel,
        ),
        OlSegmented<Gender>(
          segments: {for (final g in Gender.values) g: g.label},
          value: _gender,
          onChanged: (v) => setState(() => _gender = v),
        ),
        const OlOverline('Kontak'),
        OlTextField(
          label: 'Nomor HP',
          isRequired: true,
          controller: _phone,
          keyboardType: TextInputType.phone,
          error: _phoneError,
          onChanged: touch,
        ),
        OlTextField(
          label: 'Alamat',
          controller: _address,
          helper: 'Tambahkan pin peta bila pasien memakai home visit.',
        ),
        const OlOverline('Fisik & lainnya'),
        pair(
          OlTextField(
            label: 'Tinggi badan',
            controller: _tb,
            suffixText: 'cm',
            error: _err('height_cm'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          OlTextField(
            label: 'Berat badan',
            controller: _bb,
            suffixText: 'kg',
            error: _err('weight_kg'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        pair(
          OlTextField(label: 'Pekerjaan / instansi', controller: _job),
          OlTextField(label: 'Hobi / olahraga', controller: _hobby),
        ),
        OlTextField(label: 'Keluhan awal', controller: _complaint, maxLines: 3),
        if (_editMode)
          const SizedBox.shrink()
        else
          // ConsentCheckbox (§4): wajib dicentang aktif, teks bisa dibuka penuh.
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OlCheckbox(
                  label: 'Pasien menyetujui penggunaan data kesehatan *',
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.feedback.sheet<void>(
                      title: 'Persetujuan penggunaan data',
                      message:
                          'Data identitas & kesehatan dipakai untuk layanan terapi, sesuai UU PDP No. 27/2022. Pasien dapat meminta salinan atau penghapusan data.',
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
                    child: const Text('Baca kebijakan'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

int parseIntOr0(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Field tanggal lahir: ketuk → pemilih tanggal (mulai dari tahun).
class _BirthField extends StatelessWidget {
  const _BirthField({required this.value, required this.onTap, this.error});

  final DateTime? value;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Tanggal lahir'),
              TextSpan(
                text: ' *',
                style: TextStyle(color: c.crit),
              ),
            ],
          ),
          style: t.fieldLabel,
        ),
        const SizedBox(height: 8),
        Semantics(
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
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error!, style: t.caption.copyWith(color: c.crit)),
        ],
      ],
    );
  }
}
