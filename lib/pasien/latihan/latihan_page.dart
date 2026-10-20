import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

/// PS-06 Program latihan (tab Latihan): kepatuhan minggu ini, latihan hari ini dengan centang.
class LatihanPage extends ConsumerStatefulWidget {
  const LatihanPage({super.key});

  @override
  ConsumerState<LatihanPage> createState() => _LatihanPageState();
}

class _LatihanPageState extends ConsumerState<LatihanPage> {
  int _gen = 0;
  final _done = <String, bool>{};

  Future<void> _toggle(ProgramItemV it, bool done) async {
    setState(() => _done[it.id] = done);
    final ok = await runApi(context, () => ref.read(pasienAppApiProvider).logExercise(it.id, done: done).then((_) => true));
    if (!mounted) return;
    if (ok == null) {
      setState(() => _done.remove(it.id));
    } else if (done) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) => OlPageBody(
    header: const OlAppHeader(title: 'Latihan'),
    children: [
      OlAsync<List<ProgramV>>(
        key: ValueKey(_gen),
        load: ref.read(pasienAppApiProvider).programs,
        builder: (context, all, _) {
          final c = context.ol;
          final t = context.olText;
          final active = [for (final p in all) if (p.status == 'active') p];
          if (active.isEmpty) {
            return const [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptyInbox,
                  title: 'Belum ada program latihan',
                  message: 'Terapis mengirim latihan rumah setelah sesi. Program muncul di sini.',
                ),
              ),
            ];
          }
          return [
            for (final p in active) ...[
              OlCard(
                variant: OlCardVariant.now,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Kepatuhan minggu ini', style: t.body.copyWith(color: c.muted)),
                    Text('${p.adherence}%', style: t.display),
                    OlMeterRow(label: 'dari terapis ${p.therapistName}', value: p.adherence, max: 100),
                    if (p.endsOn != null) Text('Program sampai ${Fmt.dateNoDay(p.endsOn!)}', style: t.caption.copyWith(color: c.muted)),
                    if (p.note != null && p.note!.isNotEmpty) ...[
                      const SizedBox(height: OlSpace.sm),
                      Text('"${p.note}"', style: t.body),
                    ],
                  ],
                ),
              ),
              const OlSectionHeader(title: 'Hari ini'),
              OlCard(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                child: Column(
                  children: [
                    for (final it in p.items)
                      Row(
                        children: [
                          Expanded(
                            child: OlCheckbox(
                              label: it.exercise.name,
                              subtitle: it.dose,
                              strikeWhenChecked: true,
                              value: _done[it.id] ?? it.doneToday,
                              onChanged: (v) => _toggle(it, v),
                            ),
                          ),
                          OlIconButton(
                            icon: OlIcons.chevronRight,
                            semanticLabel: 'Lihat ${it.exercise.name}',
                            onPressed: () async {
                              await context.push(PRoutes.latihanDetail(it.id));
                              if (mounted) setState(() => _gen++);
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            Text('Hentikan latihan bila nyeri bertambah dan beri tahu terapis Anda.', style: t.caption.copyWith(color: c.muted)),
          ];
        },
      ),
    ],
  );
}
