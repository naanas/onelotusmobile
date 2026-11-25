import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/models/exam.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'pemeriksaan_form_page.dart';

typedef _Detail = ({Patient patient, List<ExamV> exams, PageResult<SessionRecord> records});

/// Detail pasien untuk terapis & admin (seperti halaman detail pasien di sistem Laravel lama):
/// data diri (bisa diubah), riwayat pemeriksaan (tambah / ubah / hapus), dan rekam sesi dari jadwal bila ada.
class PasienDetailPage extends ConsumerStatefulWidget {
  const PasienDetailPage({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PasienDetailPage> createState() => _PasienDetailPageState();
}

class _PasienDetailPageState extends ConsumerState<PasienDetailPage> {
  int _gen = 0;

  OneLotusApi get _api => ref.read(oneLotusApiProvider);

  Future<_Detail> _load() async {
    final r = await (
      _api.patient(widget.patientId),
      _api.exams(widget.patientId),
      _api.patientRecords(widget.patientId).catchError((_) => const PageResult<SessionRecord>(items: [])),
    ).wait;
    return (patient: r.$1, exams: r.$2, records: r.$3);
  }

  void _reload() => setState(() => _gen++);

  Future<void> _openExam([ExamV? exam]) async {
    final saved = await Navigator.of(context).push<ExamV>(
      MaterialPageRoute(builder: (_) => PemeriksaanFormPage(patientId: widget.patientId, exam: exam)),
    );
    if (saved != null && mounted) _reload();
  }

  Future<void> _deleteExam(ExamV e) async {
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: 'Hapus pemeriksaan?',
        message: 'Pemeriksaan ${e.date == null ? '' : Fmt.dateNoDay(e.date!)} akan dihapus. Isinya tetap tercatat di audit log.',
        confirmLabel: 'Hapus',
      ),
    );
    if (!ok || !mounted) return;
    final done = await runApi(context, () => _api.deleteExam(e.id).then((_) => true));
    if (done == true && mounted) {
      context.feedback.success('Pemeriksaan dihapus.');
      _reload();
    }
  }

  Future<void> _edit() async {
    await context.push('${Routes.kasirPasienForm}?pasien=${widget.patientId}');
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Detail pasien',
    foot: [
      OlButton(label: 'Tambah pemeriksaan', icon: OlIcons.plus, onPressed: () => _openExam()),
    ],
    children: [
      OlAsync<_Detail>(
        key: ValueKey(_gen),
        load: _load,
        builder: (context, d, _) => _content(context, d),
      ),
    ],
  );

  List<Widget> _content(BuildContext context, _Detail d) {
    final c = context.ol;
    final t = context.olText;
    final p = d.patient;
    final age = p.ageOn(DateTime.now());
    final info = <(String, String)>[
      if (p.birthDate != null)
        ('Tempat, tgl lahir', [if (p.birthPlace != null) p.birthPlace!, Fmt.dateNoDay(p.birthDate!)].join(', ')),
      if (p.phone != null) ('No. HP', p.phone!),
      if (p.address != null) ('Alamat', p.address!),
      if (p.institution != null) ('Instansi', p.institution!),
      if (p.hobby != null) ('Hobi / kegiatan', p.hobby!),
      if (p.heightCm != null || p.weightKg != null)
        (
          'TB / BB',
          [
            if (p.heightCm != null) '${p.heightCm!.round()} cm',
            if (p.weightKg != null) '${p.weightKg!.round()} kg',
          ].join(' · '),
        ),
    ];
    return [
      Row(
        children: [
          OlAvatar(name: p.name, large: true),
          const SizedBox(width: OlSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(p.name, style: t.title)),
                const SizedBox(height: 2),
                Text(
                  [Fmt.patientNo(p.number), if (age != null) '$age th', if (p.gender != null) p.gender!.label].join(' · '),
                  style: t.body.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          OlButton.text(label: 'Ubah', small: true, onPressed: _edit),
        ],
      ),
      if (p.medicalAlert != null) OlBanner(tone: OlBannerTone.crit, message: p.medicalAlert!),
      if (info.isNotEmpty)
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, (k, v)) in info.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                Text(k, style: t.caption),
                Text(v, style: t.body.copyWith(fontSize: 15)),
              ],
            ],
          ),
        ),
      OlSectionHeader(title: 'Pemeriksaan (${d.exams.length})'),
      if (d.exams.isEmpty)
        OlCard(
          child: EmptyState(
            illustration: OlIllustration.emptySchedule,
            title: 'Belum ada pemeriksaan',
            message: 'Tekan "Tambah pemeriksaan" untuk mencatat hasil pemeriksaan pasien ini.',
          ),
        )
      else
        for (final e in d.exams) _ExamCard(exam: e, onEdit: () => _openExam(e), onDelete: () => _deleteExam(e)),
      if (d.records.items.isNotEmpty) ...[
        const OlSectionHeader(title: 'Rekam sesi dari jadwal'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, r) in d.records.items.indexed)
                OlListItem(
                  title: r.complaint.isEmpty ? 'Rekam sesi' : r.complaint,
                  subtitle: [
                    if (r.updatedAt != null) Fmt.dateNoDay(r.updatedAt!),
                    if (r.treatments.isNotEmpty) r.treatments.join(', '),
                  ].join(' · '),
                  divider: i < d.records.items.length - 1,
                  onTap: () => context.push(Routes.terapisSesi(r.sessionId)),
                ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onEdit, required this.onDelete});
  final ExamV exam;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OlIcon(OlIcons.calendar, color: c.brand, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  exam.date == null ? 'Tanpa tanggal' : Fmt.date(exam.date!),
                  style: t.bodyStrong.copyWith(fontSize: 15),
                ),
              ),
              if (exam.therapistName != null) OlTag(exam.therapistName!, tone: OlTagTone.muted),
            ],
          ),
          const SizedBox(height: 8),
          for (final f in exam.fields.entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${f.key}: ', style: t.body.copyWith(color: c.muted)),
                    TextSpan(text: f.value),
                  ],
                ),
                style: t.body,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OlButton.text(label: 'Hapus', small: true, onPressed: onDelete),
              const SizedBox(width: 4),
              OlButton.text(label: 'Ubah', small: true, onPressed: onEdit),
            ],
          ),
        ],
      ),
    );
  }
}
