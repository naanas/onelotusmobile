import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/body_map/body_map_selection.dart';
import '../../ui/ui.dart';

/// PS-12 Riwayat sesi versi pasien: area, nyeri, perawatan, saran — tanpa catatan internal terapis (§5.13, §10).
class RiwayatSesiPage extends ConsumerWidget {
  const RiwayatSesiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OlDetailScaffold(
    title: 'Riwayat sesi',
    children: [
      OlAsync<List<PatientSessionV>>(
        load: ref.read(pasienAppApiProvider).sessions,
        builder: (context, list, _) {
          final c = context.ol;
          final t = context.olText;
          if (list.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptySchedule, title: 'Belum ada riwayat', message: 'Ringkasan setiap sesi terapi Anda muncul di sini.'))];
          }
          return [
            for (final s in list)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.date(s.date.toLocal()), style: t.heading),
                    Text([s.serviceName, s.therapistName].where((x) => x.isNotEmpty).join(' · '), style: t.body.copyWith(color: c.muted)),
                    if (s.painBefore != null || s.painAfter != null) ...[
                      const SizedBox(height: OlSpace.sm),
                      Text('Nyeri ${s.painBefore ?? '-'} → ${s.painAfter ?? '-'} (skala 0–10)', style: t.bodyStrong),
                    ],
                    if (s.areas.isNotEmpty) ...[
                      const SizedBox(height: OlSpace.xs),
                      Text('Area: ${{for (final a in s.areas) bodyAreaNames[a] ?? a}.join(', ')}', style: t.body),
                    ],
                    if (s.treatments.isNotEmpty) Text('Perawatan: ${s.treatments.join(', ')}', style: t.body),
                    if (s.conclusion != null && s.conclusion!.isNotEmpty) ...[
                      const SizedBox(height: OlSpace.sm),
                      Text('Saran terapis', style: t.caption.copyWith(color: c.muted)),
                      Text(s.conclusion!, style: t.body),
                    ],
                  ],
                ),
              ),
          ];
        },
      ),
    ],
  );
}
