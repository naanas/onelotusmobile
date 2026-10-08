import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-04 Tambah / verifikasi data pasien (form intake). Nomor pasien dibuat otomatis.
/// Persetujuan PDP wajib untuk pasien baru (§5.11).
class PasienFormPage extends StatefulWidget {
  const PasienFormPage({super.key});

  @override
  State<PasienFormPage> createState() => _PasienFormPageState();
}

class _PasienFormPageState extends State<PasienFormPage> {
  final _name = TextEditingController(text: 'Sari Wulandari');
  final _birth = TextEditingController(text: '14 Feb 1994');
  final _place = TextEditingController(text: 'Malang');
  final _phone = TextEditingController(text: '0812 3456');
  final _address = TextEditingController(
    text: 'Jl. Bunga Kopi No. 8, Lowokwaru',
  );
  final _tb = TextEditingController(text: '162');
  final _bb = TextEditingController(text: '55');
  final _job = TextEditingController(text: 'Guru SD');
  final _hobby = TextEditingController(text: 'Yoga');
  final _complaint = TextEditingController(
    text: 'Nyeri pinggang bawah 2 minggu',
  );
  String _gender = 'P';
  bool _consent = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _birth,
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
  String? get _phoneError => _digits.isNotEmpty && _digits.length < 10
      ? 'Nomor HP belum lengkap — minimal 10 digit, mis. 0812 3456 7890.'
      : null;
  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _birth.text.trim().isNotEmpty &&
      _digits.length >= 10 &&
      _consent;

  Future<void> _save() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _busy = false);
    // Contoh alur §12.4 duplicate_patient sebelum membuat nomor baru.
    final choice = await showDuplicatePatientSheet(
      context,
      existing: const PatientBrief(
        name: 'Sari Wulandari',
        number: '#0291',
        detail: '14 Feb 1994 · HP berakhiran 4417 · 6 sesi',
      ),
      incoming: PatientBrief(
        name: 'Sari Wulandari',
        detail:
            'Sari Wulandari · 14 Feb 1994 · HP berakhiran ${_digits.length >= 4 ? _digits.substring(_digits.length - 4) : '–'}',
      ),
    );
    final openOld = choice == null
        ? null
        : choice == DuplicateChoice.openExisting;
    if (!mounted || openOld == null) return;
    context.feedback.success(
      openOld
          ? 'Data lama dibuka. Penggabungan hanya oleh admin/owner.'
          : 'Pasien #0413 dibuat.',
      action: openOld ? null : FeedbackAction('Jadwalkan', () {}),
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _archive() async {
    final ok = await context.feedback.confirm(
      const ConfirmSpec(
        title: 'Arsipkan data Sari Wulandari?',
        message:
            'Pasien tidak muncul di daftar aktif. Riwayat terapi tetap tersimpan dan bisa dipulihkan oleh admin atau owner.',
        confirmLabel: 'Arsipkan',
      ),
    );
    if (ok && mounted) {
      context.feedback.success('Data pasien diarsipkan.');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
    void touch(String _) => setState(() {});

    return OlDetailScaffold(
      title: 'Verifikasi pasien baru',
      context_: 'Dari intake QR · 14.41',
      foot: [
        OlButton(
          label: 'Simpan & buat nomor pasien',
          loading: _busy,
          onPressed: _valid ? _save : null,
        ),
        OlButton(
          label: 'Arsipkan',
          variant: OlButtonVariant.dangerText,
          expand: true,
          onPressed: _archive,
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
                'Otomatis saat disimpan',
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
          onChanged: touch,
        ),
        pair(
          OlTextField(
            label: 'Tanggal lahir',
            isRequired: true,
            controller: _birth,
            onChanged: touch,
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
        OlSegmented<String>(
          segments: const {'L': 'Laki-laki', 'P': 'Perempuan'},
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
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          OlTextField(
            label: 'Berat badan',
            controller: _bb,
            suffixText: 'kg',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        pair(
          OlTextField(label: 'Pekerjaan / instansi', controller: _job),
          OlTextField(label: 'Hobi / olahraga', controller: _hobby),
        ),
        OlTextField(label: 'Keluhan awal', controller: _complaint),
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
