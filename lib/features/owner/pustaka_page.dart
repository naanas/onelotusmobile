import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/body_map/body_map_selection.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'owner_widgets.dart';

const _levels = {'easy': 'Mudah', 'medium': 'Sedang', 'hard': 'Berat'};

/// OW-15 Pustaka latihan: daftar latihan per area, usulan terapis (disetujui di Persetujuan),
/// tambah/ubah latihan dengan video.
class PustakaPage extends ConsumerStatefulWidget {
  const PustakaPage({super.key});

  @override
  ConsumerState<PustakaPage> createState() => _PustakaPageState();
}

class _PustakaPageState extends ConsumerState<PustakaPage> {
  int _gen = 0;
  String? _area;

  Future<void> _edit([ExerciseV? e]) async {
    final name = TextEditingController(text: e?.name ?? '');
    final video = TextEditingController(text: e?.videoUrl ?? '');
    final steps = TextEditingController(text: e?.steps.join('\n') ?? '');
    final sets = TextEditingController(text: e?.sets?.toString() ?? '');
    final reps = TextEditingController(text: e?.reps?.toString() ?? '');
    final dur = TextEditingController(text: e?.durationSec?.toString() ?? '');
    final warn = TextEditingController(text: e?.warnings ?? '');
    final areas = {...?e?.areas};
    String? level = e?.level;
    var archived = e?.status == 'archived';
    final ok = await formSheet(
      context,
      title: e == null ? 'Latihan baru' : 'Ubah latihan',
      fields: (set) => [
        OlTextField(label: 'Nama latihan', controller: name, isRequired: true),
        OlSelectField<String?>(
          label: 'Level',
          sheetTitle: 'Level',
          value: level,
          options: {null: 'Tidak ditentukan', ..._levels},
          onChanged: (v) => set(() => level = v),
        ),
        Wrap(
          spacing: OlSpace.xs,
          runSpacing: OlSpace.xs,
          children: [
            for (final MapEntry(:key, :value) in bodyAreaNames.entries)
              OlChip(label: value, small: true, selected: areas.contains(key), onTap: () => set(() => areas.contains(key) ? areas.remove(key) : areas.add(key))),
          ],
        ),
        OlTextField(label: 'Langkah (satu per baris)', controller: steps, maxLines: 5),
        Row(
          children: [
            Expanded(child: OlTextField(label: 'Set', controller: sets, keyboardType: TextInputType.number)),
            const SizedBox(width: OlSpace.md),
            Expanded(child: OlTextField(label: 'Repetisi', controller: reps, keyboardType: TextInputType.number)),
            const SizedBox(width: OlSpace.md),
            Expanded(child: OlTextField(label: 'Detik', controller: dur, keyboardType: TextInputType.number)),
          ],
        ),
        OlTextField(label: 'Tautan video', controller: video, keyboardType: TextInputType.url),
        OlTextField(label: 'Peringatan', controller: warn, maxLines: 2),
        if (e != null) OwToggleRow(label: 'Arsipkan', subtitle: 'Tidak muncul di pilihan terapis', value: archived, onChanged: (v) => set(() => archived = v)),
      ],
    );
    if (!ok || !mounted) return;
    int? n(TextEditingController c) => c.text.trim().isEmpty ? null : parseAmount(c.text);
    String? s(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final r = await runApi(
      context,
      () => ref.read(billingApiProvider).saveExercise(e?.id, {
        'name': name.text.trim(),
        'level': level,
        'body_area_codes': areas.toList(),
        'steps': [for (final l in steps.text.split('\n')) if (l.trim().isNotEmpty) l.trim()],
        'default_sets': n(sets),
        'default_reps': n(reps),
        'default_duration_sec': n(dur),
        'video_url': s(video),
        'warnings': s(warn),
        if (e != null && e.status != 'proposed') 'status': archived ? 'archived' : 'approved',
      }),
    );
    if (r == null || !mounted) return;
    context.feedback.success('Latihan disimpan.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Pustaka latihan',
    foot: [OlButton(label: 'Tambah latihan', icon: OlIcons.plus, onPressed: _edit)],
    children: [
      OlAsync<List<ExerciseV>>(
        key: ValueKey(_gen),
        load: ref.read(billingApiProvider).exercises,
        builder: (context, all, _) {
          final c = context.ol;
          final t = context.olText;
          final proposed = [for (final e in all) if (e.status == 'proposed') e];
          final areas = {for (final e in all) ...e.areas}.toList()..sort();
          final shown = [for (final e in all) if (e.status != 'proposed' && e.status != 'rejected' && (_area == null || e.areas.contains(_area))) e];
          return [
            if (proposed.isNotEmpty)
              OlCard(
                onTap: () => context.push(Routes.ownerPersetujuan),
                child: Row(
                  children: [
                    Expanded(child: Text('${proposed.length} usulan latihan dari terapis menunggu persetujuan', style: t.bodyStrong)),
                    OlIcon(OlIcons.chevronRight, color: c.faint),
                  ],
                ),
              ),
            if (areas.isNotEmpty)
              Wrap(
                spacing: OlSpace.sm,
                runSpacing: OlSpace.sm,
                children: [
                  OlChip(label: 'Semua', small: true, selected: _area == null, onTap: () => setState(() => _area = null)),
                  for (final a in areas) OlChip(label: bodyAreaNames[a] ?? a, small: true, selected: _area == a, onTap: () => setState(() => _area = a)),
                ],
              ),
            if (shown.isEmpty)
              const OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada latihan', message: 'Latihan di pustaka bisa dikirim terapis ke aplikasi pasien.'))
            else
              OlCard(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                child: Column(
                  children: [
                    for (final (n, e) in shown.indexed)
                      OlListItem(
                        title: e.name,
                        subtitle: [
                          if (e.level != null) _levels[e.level] ?? e.level!,
                          e.areas.map((a) => bodyAreaNames[a] ?? a).join(', '),
                          if (e.videoUrl != null) 'video',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        trailing: e.status == 'archived' ? const OlTag('Arsip', tone: OlTagTone.muted) : null,
                        divider: n < shown.length - 1,
                        onTap: () => _edit(e),
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
