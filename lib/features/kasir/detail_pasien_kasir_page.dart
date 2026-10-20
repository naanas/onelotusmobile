import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../shared/patient_list.dart';

typedef _Detail = ({Patient patient, PageResult<SessionRecord> records});

/// KS-05 Detail pasien (kasir; juga owner OW-03): identitas & kontak lengkap, paket, riwayat
/// kunjungan ringkas (catatan medis hanya ringkasan, §7). Aksi: edit, buat jadwal, arsip,
/// pulihkan dari arsip (owner).
class DetailPasienKasirPage extends ConsumerStatefulWidget {
  const DetailPasienKasirPage({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<DetailPasienKasirPage> createState() =>
      _DetailPasienKasirPageState();
}

class _DetailPasienKasirPageState extends ConsumerState<DetailPasienKasirPage> {
  int _gen = 0;

  OneLotusApi get _api => ref.read(oneLotusApiProvider);

  Future<_Detail> _load() async {
    final r = await (
      _api.patient(widget.patientId),
      _api.patientRecords(widget.patientId),
    ).wait;
    return (patient: r.$1, records: r.$2);
  }

  void _reload() => setState(() => _gen++);

  Future<void> _archive(Patient p, bool archive) async {
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: archive ? 'Arsipkan ${p.name}?' : 'Pulihkan ${p.name}?',
        message: archive
            ? 'Pasien tidak muncul di daftar aktif. Riwayat terapi tetap tersimpan dan bisa dipulihkan owner.'
            : 'Pasien kembali muncul di daftar aktif.',
        confirmLabel: archive ? 'Arsipkan' : 'Pulihkan',
        danger: archive,
      ),
    );
    if (!ok || !mounted) return;
    try {
      archive
          ? await _api.archivePatient(p.id)
          : await _api.restorePatient(p.id);
      if (!mounted) return;
      context.feedback.success(
        archive ? 'Data pasien diarsipkan.' : 'Pasien dipulihkan.',
      );
      _reload();
    } on AppError catch (e) {
      if (!mounted) return;
      final msg = e.fieldErrors.values.expand((v) => v).firstOrNull;
      msg != null ? context.feedback.info(msg) : context.feedback.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner =
        ref.watch(authProvider.select((a) => a.activeRole)) == Role.owner;
    return OlDetailScaffold(
      title: 'Detail pasien',
      actions: [
        OlButton.secondary(
          label: 'Edit',
          small: true,
          expand: false,
          onPressed: () async {
            await context.push(
              '${Routes.kasirPasienForm}?pasien=${widget.patientId}',
            );
            _reload();
          },
        ),
      ],
      foot: [
        OlButton.secondary(
          label: 'Jual paket',
          icon: OlIcons.package,
          onPressed: () => context.push(Routes.jualPaket(widget.patientId)),
        ),
        OlButton(
          label: 'Buat jadwal',
          onPressed: () => context.push(
            '${Routes.kasirBuatJadwal}?pasien=${widget.patientId}',
          ),
        ),
      ],
      children: [
        OlAsync<_Detail>(
          key: ValueKey(_gen),
          load: _load,
          builder: (context, d, _) {
            final c = context.ol;
            final t = context.olText;
            final p = d.patient;
            final age = p.ageOn(DateTime.now());
            final pkg = p.activePackage;
            return [
              if (p.archivedAt != null)
                OlBanner(
                  tone: OlBannerTone.warn,
                  message: 'Diarsipkan ${Fmt.dateNoDay(p.archivedAt!)}.',
                  actionLabel: isOwner ? 'Pulihkan' : null,
                  onAction: isOwner ? () => _archive(p, false) : null,
                ),
              Row(
                children: [
                  OlAvatar(name: p.name, large: true),
                  const SizedBox(width: OlSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(p.name, style: t.title),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: Fmt.patientNo(p.number),
                                style: t.mono.copyWith(color: c.muted),
                              ),
                              TextSpan(
                                text: [
                                  '',
                                  if (age != null) '$age th',
                                  if (p.gender != null) p.gender!.label,
                                ].join(' · '),
                              ),
                            ],
                          ),
                          style: t.body.copyWith(color: c.muted),
                        ),
                        if (p.phone != null)
                          Text(
                            p.phone!,
                            style: t.mono.copyWith(color: c.muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (p.medicalAlert != null)
                OlBanner(tone: OlBannerTone.crit, message: p.medicalAlert!),
              OlCard(
                child: Column(
                  children: [
                    OlInfoRow(
                      label: 'Tanggal lahir',
                      value: [
                        if (p.birthPlace != null) p.birthPlace!,
                        if (p.birthDate != null) Fmt.dateNoDay(p.birthDate!),
                      ].join(', '),
                    ),
                    OlInfoRow(label: 'Alamat', value: p.address ?? '–'),
                    OlInfoRow(
                      label: 'Pekerjaan / instansi',
                      value: p.institution ?? '–',
                    ),
                    OlInfoRow(label: 'Hobi', value: p.hobby ?? '–'),
                    OlInfoRow(
                      label: 'TB / BB',
                      value:
                          '${p.heightCm?.round() ?? '–'} cm / ${p.weightKg?.round() ?? '–'} kg',
                    ),
                    OlInfoRow(
                      label: 'Paket',
                      value: pkg == null
                          ? 'Tidak ada'
                          : '${pkg.name} · sisa ${pkg.remaining}/${pkg.total}',
                    ),
                    OlInfoRow(
                      label: 'Kunjungan terakhir',
                      value: lastVisitLabel(p.lastVisitAt, DateTime.now()),
                    ),
                  ],
                ),
              ),
              const OlSectionHeader(title: 'Riwayat kunjungan'),
              if (d.records.items.isEmpty)
                OlCard(
                  child: Text(
                    'Belum ada rekam sesi di aplikasi baru.',
                    style: t.body.copyWith(color: c.muted),
                  ),
                )
              else
                OlCard(
                  padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                  child: Column(
                    children: [
                      for (final (i, r) in d.records.items.indexed)
                        OlListItem(
                          title: r.complaint.isEmpty ? 'Sesi' : r.complaint,
                          subtitle: [
                            if (r.updatedAt != null)
                              Fmt.dateNoDay(r.updatedAt!),
                            if (r.treatments.isNotEmpty)
                              r.treatments.join(', '),
                          ].join(' · '),
                          divider: i < d.records.items.length - 1,
                        ),
                    ],
                  ),
                ),
              if (p.archivedAt == null)
                OlButton.text(
                  label: 'Arsipkan pasien',
                  expand: true,
                  onPressed: () => _archive(p, true),
                ),
            ];
          },
        ),
      ],
    );
  }
}
