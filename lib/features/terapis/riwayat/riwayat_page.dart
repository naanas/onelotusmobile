import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';
import '../demo_data.dart';

enum _Filter { month, week, incomplete, homeVisit }

/// TR-07 Riwayat sesi (tab Riwayat terapis): dikelompokkan per hari, badge "Belum lengkap".
class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  _Filter _filter = _Filter.month;

  bool _keep(DemoHistoryRow r) => switch (_filter) {
    _Filter.month || _Filter.week => true,
    _Filter.incomplete => r.tag == DemoHistoryTag.incomplete,
    _Filter.homeVisit => r.homeVisit,
  };

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final (i, (label, rows)) in demoHistory.indexed)
        if (_filter != _Filter.week || i < 3)
          (label, rows.where(_keep).toList()),
    ].where((g) => g.$2.isNotEmpty).toList();
    final incomplete = demoHistory
        .expand((g) => g.$2)
        .where((r) => r.tag == DemoHistoryTag.incomplete)
        .length;

    Widget chip(String label, _Filter f) => OlChip(
      label: label,
      selected: _filter == f,
      onTap: () => setState(() => _filter = f),
    );

    return OlPageBody(
      header: const OlAppHeader(
        title: 'Riwayat sesi',
        context_: 'Oktober 2026 · 38 sesi',
      ),
      children: [
        Wrap(
          spacing: OlSpace.sm,
          children: [
            chip('Bulan ini', _Filter.month),
            chip('Minggu ini', _Filter.week),
            chip('Belum lengkap · $incomplete', _Filter.incomplete),
            chip('Home visit', _Filter.homeVisit),
          ],
        ),
        if (groups.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptyInbox,
              title: 'Tidak ada sesi',
              message: 'Belum ada sesi yang cocok dengan filter ini.',
            ),
          ),
        for (final (label, rows) in groups) ...[
          OlOverline(label),
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, r) in rows.indexed)
                  _HistoryRow(
                    row: r,
                    divider: i < rows.length - 1,
                    onTap: () => context.push(Routes.terapisSesi(r.sessionId)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.row,
    required this.divider,
    required this.onTap,
  });

  final DemoHistoryRow row;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final tag = switch (row.tag) {
      DemoHistoryTag.unsynced => const OlTag(
        'Belum tersinkron',
        tone: OlTagTone.warn,
      ),
      DemoHistoryTag.paid => const OlTag('Lunas', tone: OlTagTone.ok),
      DemoHistoryTag.incomplete => const OlTag(
        'Belum lengkap',
        tone: OlTagTone.crit,
      ),
      DemoHistoryTag.noShow => const OlTag(
        'Tidak datang',
        tone: OlTagTone.crit,
      ),
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
                row.time,
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
                  Text(row.name, style: t.bodyStrong.copyWith(fontSize: 15)),
                  Text(row.caption, style: t.body.copyWith(color: c.muted)),
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
