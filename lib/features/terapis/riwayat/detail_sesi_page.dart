import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/api/one_lotus_api.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/body_map/body_map_selection.dart';
import '../../../ui/ui.dart';

/// TR-08 Detail sesi: rekam sesi baca-saja (dari server, atau versi di HP yang belum terkirim).
/// Edit membuka rekam sesi (TR-04). Addendum menunggu aturan batas edit (§16 no. 7).
class DetailSesiPage extends ConsumerWidget {
  const DetailSesiPage({super.key, required this.sessionId});

  final String sessionId;

  Future<(SessionRecord?, Patient?)> _load(WidgetRef ref) async {
    final rec = await ref
        .read(sessionRecordRepositoryProvider)
        .forSession(sessionId);
    if (rec == null) return (null, null);
    final patient = await ref.read(oneLotusApiProvider).patient(rec.patientId);
    return (rec, patient);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => OlDetailScaffold(
    title: 'Detail sesi',
    actions: [
      OlButton.secondary(
        label: 'Edit',
        icon: OlIcons.edit,
        small: true,
        expand: false,
        onPressed: () => context.push(Routes.terapisRekam(sessionId)),
      ),
    ],
    children: [
      OlAsync<(SessionRecord?, Patient?)>(
        load: () => _load(ref),
        builder: (context, data, _) {
          final (rec, patient) = data;
          final c = context.ol;
          final t = context.olText;
          if (rec == null) {
            return [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptyInbox,
                  title: 'Belum ada rekam sesi',
                  message: 'Sesi ini belum dicatat.',
                  actionLabel: 'Isi rekam sesi',
                  onAction: () => context.push(Routes.terapisRekam(sessionId)),
                ),
              ),
            ];
          }
          String join(List<String> l) => l.isEmpty ? '–' : l.join(', ');
          return [
            if (patient != null)
              Text(
                '${patient.name} · ${Fmt.patientNo(patient.number)}',
                style: t.heading,
              ),
            if (rec.updatedAt != null)
              Text(
                'Disimpan ${Fmt.date(rec.updatedAt!)} ${Fmt.time(rec.updatedAt!)} · versi ${rec.version}',
                style: t.body.copyWith(color: c.muted),
              ),
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OlInfoRow(
                    label: 'Keluhan',
                    value: rec.complaint.isEmpty ? '–' : rec.complaint,
                    divider: true,
                  ),
                  if (rec.cause != null)
                    OlInfoRow(
                      label: 'Penyebab',
                      value: [
                        rec.cause!.label,
                        if (rec.injuryDuration != null)
                          '${rec.injuryDuration} ${rec.injuryDurationUnit?.label ?? ''}',
                      ].join(' · '),
                    ),
                  OlInfoRow(
                    label: 'Area ditangani',
                    value: join([
                      for (final a in rec.treatedAreas) bodyAreaLabel(a),
                    ]),
                  ),
                  if (rec.calmingAreas.isNotEmpty)
                    OlInfoRow(
                      label: 'Area penenang',
                      value: join([
                        for (final a in rec.calmingAreas) bodyAreaLabel(a),
                      ]),
                    ),
                  if (rec.painBefore != null || rec.painAfter != null)
                    OlInfoRow(
                      label: 'Nyeri',
                      value:
                          '${rec.painBefore ?? '–'}  →  ${rec.painAfter ?? '–'}',
                      valueStyle: t.heading.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  OlInfoRow(
                    label: 'Treatment',
                    value: join([
                      ...rec.treatments,
                      if (rec.treatmentNote.isNotEmpty) rec.treatmentNote,
                    ]),
                    divider: true,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Analisa (internal)',
                    style: t.body.copyWith(fontSize: 15, color: c.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    join([
                      if (rec.analysis.isNotEmpty) rec.analysis,
                      ...rec.analysisTags,
                    ]),
                    style: t.body.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kesimpulan & saran',
                    style: t.body.copyWith(fontSize: 15, color: c.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    join([
                      if (rec.conclusion.isNotEmpty) rec.conclusion,
                      ...rec.conclusionTags,
                    ]),
                    style: t.body.copyWith(fontSize: 15),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    ],
  );
}
