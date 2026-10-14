import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/api/one_lotus_api.dart';
import '../../../data/auth/auth_controller.dart';
import '../../../data/models/models.dart';
import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

enum _Filter { month, week, homeVisit }

/// TR-07 Riwayat sesi (tab Riwayat terapis): sesi selesai/tidak datang/dibatalkan milik terapis
/// login (`GET /v1/sessions`), dikelompokkan per hari, terbaru dulu.
class RiwayatPage extends ConsumerStatefulWidget {
  const RiwayatPage({super.key});

  @override
  ConsumerState<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends ConsumerState<RiwayatPage> {
  _Filter _filter = _Filter.month;
  int _gen = 0;

  static const _past = {
    SessionStatus.done,
    SessionStatus.unpaid,
    SessionStatus.paid,
    SessionStatus.noShow,
    SessionStatus.cancelled,
  };

  Future<List<Session>> _load() async {
    final auth = ref.read(authProvider);
    final branch = auth.activeBranch;
    final user = auth.user;
    if (branch == null || user == null) return const [];
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day + 1);
    final from = to.subtract(Duration(days: _filter == _Filter.week ? 7 : 31));
    final list = await ref
        .read(oneLotusApiProvider)
        .sessions(
          branchId: branch.id,
          from: from,
          to: to,
          therapistId: user.id,
        );
    return [
      for (final s in list.reversed)
        if (_past.contains(s.status) &&
            (_filter != _Filter.homeVisit || s.isHomeVisit))
          s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, _Filter f) => OlChip(
      label: label,
      selected: _filter == f,
      onTap: () => setState(() {
        _filter = f;
        _gen++;
      }),
    );

    return OlPageBody(
      header: const OlAppHeader(title: 'Riwayat sesi'),
      children: [
        Wrap(
          spacing: OlSpace.sm,
          children: [
            chip('30 hari', _Filter.month),
            chip('7 hari', _Filter.week),
            chip('Home visit', _Filter.homeVisit),
          ],
        ),
        OlAsync<List<Session>>(
          key: ValueKey(_gen),
          load: _load,
          builder: (context, list, _) {
            if (list.isEmpty) {
              return const [
                OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptyInbox,
                    title: 'Tidak ada sesi',
                    message: 'Belum ada sesi selesai pada rentang ini.',
                  ),
                ),
              ];
            }
            final groups = <DateTime, List<Session>>{};
            for (final s in list) {
              final d = DateTime(
                s.startAt.year,
                s.startAt.month,
                s.startAt.day,
              );
              (groups[d] ??= []).add(s);
            }
            return [
              for (final e in groups.entries) ...[
                OlOverline(Fmt.date(e.key)),
                OlCard(
                  padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                  child: Column(
                    children: [
                      for (final (i, s) in e.value.indexed)
                        _HistoryRow(
                          session: s,
                          divider: i < e.value.length - 1,
                          onTap: () => context.push(Routes.terapisSesi(s.id)),
                        ),
                    ],
                  ),
                ),
              ],
            ];
          },
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.session,
    required this.divider,
    required this.onTap,
  });

  final Session session;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final s = session;
    final tag = switch (s.status) {
      SessionStatus.paid => const OlTag('Lunas', tone: OlTagTone.ok),
      SessionStatus.noShow => const OlTag('Tidak datang', tone: OlTagTone.crit),
      SessionStatus.cancelled => const OlTag(
        'Dibatalkan',
        tone: OlTagTone.muted,
      ),
      _ => const OlTag('Selesai', tone: OlTagTone.brand),
    };
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                Fmt.time(s.startAt),
                style: t.mono.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.patientName,
                    style: t.bodyStrong.copyWith(fontSize: 15),
                  ),
                  Text(
                    [
                      s.serviceName,
                      if (s.isHomeVisit) 'home visit',
                    ].join(' · '),
                    style: t.body.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: OlSpace.sm),
            tag,
          ],
        ),
      ),
    );
  }
}
