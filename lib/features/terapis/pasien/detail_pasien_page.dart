import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/api/one_lotus_api.dart';
import '../../../data/models/models.dart';
import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

typedef _Detail = ({
  Patient patient,
  PageResult<SessionRecord> records,
  List<LegacyRecord> legacy,
});

/// TR-05 Detail pasien: profil, peringatan medis, tren nyeri, paket, riwayat rekam sesi,
/// catatan lama Laravel (baca-saja). Telepon & alamat disaring server untuk terapis (§7, §10).
class DetailPasienPage extends ConsumerWidget {
  const DetailPasienPage({super.key, required this.patientId});

  final String patientId;

  Future<_Detail> _load(OneLotusApi api) async {
    final r = await (
      api.patient(patientId),
      api.patientRecords(patientId),
      api.legacyRecords(patientId),
    ).wait;
    return (patient: r.$1, records: r.$2, legacy: r.$3);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => OlDetailScaffold(
    title: 'Detail pasien',
    children: [
      OlAsync<_Detail>(
        load: () => _load(ref.read(oneLotusApiProvider)),
        builder: (context, d, _) => _content(context, d),
      ),
    ],
  );

  List<Widget> _content(BuildContext context, _Detail d) {
    final c = context.ol;
    final t = context.olText;
    final p = d.patient;
    final now = DateTime.now();
    final age = p.ageOn(now);
    // Nyeri sebelum sesi, urut lama → baru.
    final pain = [
      for (final r in d.records.items.reversed)
        if (r.painBefore != null) r.painBefore!,
    ];
    final body = [
      if (p.heightCm != null) 'TB ${p.heightCm!.round()} cm',
      if (p.weightKg != null) 'BB ${p.weightKg!.round()} kg',
    ];
    final pkg = p.activePackage;

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
                          if (p.hobby != null) p.hobby!,
                        ].join(' · '),
                      ),
                    ],
                  ),
                  style: t.body.copyWith(color: c.muted),
                ),
                if (body.isNotEmpty)
                  Text(
                    body.join(' · '),
                    style: t.body.copyWith(color: c.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
      if (p.medicalAlert != null)
        OlBanner(tone: OlBannerTone.crit, message: p.medicalAlert!),
      if (pain.length > 1)
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tren nyeri', style: t.heading.copyWith(fontSize: 17)),
              const SizedBox(height: 4),
              Text(
                '${pain.length} sesi terakhir (sebelum sesi)',
                style: t.caption.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 12),
              PainTrendChart(
                values: pain,
                startLabel: 'Sesi awal',
                endLabel: 'Terakhir',
              ),
            ],
          ),
        ),
      OlCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paket aktif', style: t.caption.copyWith(fontSize: 13)),
            Text(
              pkg?.name ?? 'Tidak ada',
              style: t.bodyStrong.copyWith(fontSize: 15),
            ),
            if (pkg != null) ...[
              const SizedBox(height: 6),
              OlTag(
                'Sisa ${pkg.remaining} dari ${pkg.total} sesi',
                tone: pkg.almostEmpty ? OlTagTone.warn : OlTagTone.brand,
              ),
            ],
          ],
        ),
      ),
      const OlSectionHeader(title: 'Riwayat rekam sesi'),
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
                  title: r.complaint.isEmpty ? 'Rekam sesi' : r.complaint,
                  subtitle: [
                    if (r.updatedAt != null) Fmt.dateNoDay(r.updatedAt!),
                    if (r.painBefore != null && r.painAfter != null)
                      'nyeri ${r.painBefore} → ${r.painAfter}',
                    if (r.treatments.isNotEmpty) r.treatments.join(', '),
                  ].join(' · '),
                  divider: i < d.records.items.length - 1,
                  onTap: () => context.push(Routes.terapisSesi(r.sessionId)),
                ),
            ],
          ),
        ),
      if (d.legacy.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Catatan lama', style: t.heading)),
                  const OlTag('Sistem lama · baca-saja', tone: OlTagTone.muted),
                ],
              ),
              for (final l in d.legacy) ...[
                const SizedBox(height: 10),
                Text(
                  Fmt.dateNoDay(l.date),
                  style: t.bodyStrong.copyWith(fontSize: 14),
                ),
                for (final e in l.fields.entries)
                  Text(
                    '${e.key}: ${e.value}',
                    style: t.body.copyWith(color: c.muted),
                  ),
              ],
            ],
          ),
        ),
      OlCard(
        child: Row(
          children: [
            OlIcon(OlIcons.phone, color: c.muted),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kontak pasien',
                    style: t.bodyStrong.copyWith(fontSize: 15),
                  ),
                  Text(
                    p.phone ?? 'Nomor hanya terlihat oleh front desk',
                    style: (p.phone == null ? t.body : t.mono).copyWith(
                      color: c.muted,
                    ),
                  ),
                  if (p.address != null)
                    Text(p.address!, style: t.body.copyWith(color: c.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
