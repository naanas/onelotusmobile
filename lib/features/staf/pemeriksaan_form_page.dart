import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/exam.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';

/// Tambah / ubah pemeriksaan pasien — isian sama dengan form pemeriksaan sistem Laravel lama:
/// tanggal periksa, keluhan, penyebab, lama cedera, analisa, treatment, bagian penenang, kesimpulan,
/// terapis, hasil rontgen. Mengembalikan [ExamV] tersimpan (atau null bila batal).
class PemeriksaanFormPage extends ConsumerStatefulWidget {
  const PemeriksaanFormPage({super.key, required this.patientId, this.exam});

  final String patientId;
  final ExamV? exam;

  @override
  ConsumerState<PemeriksaanFormPage> createState() => _PemeriksaanFormPageState();
}

class _PemeriksaanFormPageState extends ConsumerState<PemeriksaanFormPage> {
  late DateTime _date = widget.exam?.date ?? DateUtils.dateOnly(DateTime.now());
  late final _complaint = TextEditingController(text: widget.exam?.complaint);
  late final _cause = TextEditingController(text: widget.exam?.cause);
  late final _duration = TextEditingController(text: widget.exam?.injuryDuration);
  late final _analysis = TextEditingController(text: widget.exam?.analysis);
  late final _treatment = TextEditingController(text: widget.exam?.treatment);
  late final _calming = TextEditingController(text: widget.exam?.calmingArea);
  late final _conclusion = TextEditingController(text: widget.exam?.conclusion);
  late final _therapist = TextEditingController(
    text: widget.exam?.therapistName ?? ref.read(authProvider).user?.name,
  );
  late final _xray = TextEditingController(text: widget.exam?.xray);
  String? _error;
  bool _busy = false;

  List<TextEditingController> get _all =>
      [_complaint, _cause, _duration, _analysis, _treatment, _calming, _conclusion, _therapist, _xray];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2015),
      lastDate: now,
      locale: const Locale('id'),
      helpText: 'Tanggal periksa',
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if ([_complaint, _analysis, _treatment, _conclusion].every((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'Isi minimal keluhan, analisa, treatment, atau kesimpulan.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final body = {
      'record_date':
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
      'complaint': _v(_complaint),
      'cause': _v(_cause),
      'injury_duration': _v(_duration),
      'analysis': _v(_analysis),
      'treatment': _v(_treatment),
      'calming_area': _v(_calming),
      'conclusion': _v(_conclusion),
      'therapist_name': _v(_therapist),
      'xray_note': _v(_xray),
    };
    final api = ref.read(oneLotusApiProvider);
    final saved = await runApi(
      context,
      () => widget.exam == null ? api.createExam(widget.patientId, body) : api.updateExam(widget.exam!.id, body),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    context.feedback.success(widget.exam == null ? 'Pemeriksaan tersimpan.' : 'Pemeriksaan diperbarui.');
    context.pop(saved);
  }

  Widget _field(String label, TextEditingController c, {int lines = 2, String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: OlSpace.md),
    child: OlTextField(label: label, controller: c, maxLines: lines, hint: hint),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: widget.exam == null ? 'Tambah pemeriksaan' : 'Ubah pemeriksaan',
      foot: [OlButton(label: 'Simpan pemeriksaan', loading: _busy, onPressed: _save)],
      children: [
        OlCard(
          onTap: _pickDate,
          child: Row(
            children: [
              OlIcon(OlIcons.calendar, color: c.brand),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tanggal periksa', style: t.caption),
                    Text(Fmt.date(_date), style: t.bodyStrong),
                  ],
                ),
              ),
              OlIcon(OlIcons.edit, color: c.muted, size: 20),
            ],
          ),
        ),
        if (_error != null) OlBanner(tone: OlBannerTone.crit, message: _error!),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field('Keluhan', _complaint, lines: 3, hint: 'Mis. nyeri lutut kanan saat naik tangga'),
              _field('Penyebab', _cause, lines: 1, hint: 'Mis. olahraga, jatuh'),
              _field('Lama cedera', _duration, lines: 1, hint: 'Mis. 2 minggu'),
              _field('Analisa', _analysis, lines: 3),
              _field('Treatment', _treatment, lines: 3),
              _field('Bagian penenang', _calming),
              _field('Kesimpulan', _conclusion, lines: 3),
              _field('Terapis', _therapist, lines: 1),
              _field('Hasil rontgen', _xray, hint: 'Catatan hasil rontgen (opsional)'),
            ],
          ),
        ),
      ],
    );
  }
}
