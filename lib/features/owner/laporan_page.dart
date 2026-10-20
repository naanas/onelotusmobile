import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'ekspor_page.dart';

enum _Range { week, month, lastMonth }

/// OW-04 Laporan (tab Laporan owner): omzet per hari, layanan, terapis, retensi, home visit. Ekspor ke OW-05.
class LaporanPage extends ConsumerStatefulWidget {
  const LaporanPage({super.key});

  @override
  ConsumerState<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends ConsumerState<LaporanPage> {
  _Range _range = _Range.month;
  String _report = 'top_services';

  (DateTime, DateTime) get _dates {
    final now = DateTime.now();
    return switch (_range) {
      _Range.week => (DateTime(now.year, now.month, now.day - 6), now),
      _Range.month => (DateTime(now.year, now.month), now),
      _Range.lastMonth => (DateTime(now.year, now.month - 1), DateTime(now.year, now.month, 0)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (from, to) = _dates;
    final api = ref.read(billingApiProvider);
    return OlPageBody(
      header: OlAppHeader(
        title: 'Laporan',
        actions: [
          OlIconButton(icon: OlIcons.download, semanticLabel: 'Ekspor', onPressed: () => context.push(Routes.ownerEkspor)),
        ],
      ),
      children: [
        OlSegmented<_Range>(
          segments: const {_Range.week: '7 hari', _Range.month: 'Bulan ini', _Range.lastMonth: 'Bulan lalu'},
          value: _range,
          onChanged: (r) => setState(() => _range = r),
        ),
        OlAsync<ReportSummaryV>(
          key: ValueKey(('sum', _range)),
          load: () => api.summary(from: from, to: to),
          builder: (context, s, _) {
            final c = context.ol;
            final t = context.olText;
            final maxSessions = s.byTherapist.fold(1, (m, x) => x.sessions > m ? x.sessions : m);
            return [
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pendapatan', style: t.body.copyWith(color: c.muted)),
                    Text(Fmt.money(s.revenue), style: t.display),
                    if (s.deltaPct != 0)
                      Text(
                        '${s.deltaPct > 0 ? '▲' : '▼'} ${s.deltaPct.abs().toStringAsFixed(1)}% dari periode sebelumnya',
                        style: t.caption.copyWith(color: s.deltaPct > 0 ? c.ok : c.crit),
                      ),
                    if (s.series.isNotEmpty) ...[
                      const SizedBox(height: OlSpace.md),
                      OlBarChart(
                        semanticLabel: 'Pendapatan per hari',
                        bars: [for (final x in s.series) OlBar(x.label, x.value.toDouble(), display: Fmt.money(x.value))],
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(child: _Stat(label: 'Pasien kembali', value: '${s.returningPct.round()}%')),
                  const SizedBox(width: OlSpace.gap),
                  Expanded(child: _Stat(label: 'Slot terisi', value: '${s.utilizationPct.round()}%')),
                ],
              ),
              if (s.byTherapist.isNotEmpty) ...[
                const OlSectionHeader(title: 'Sesi per terapis'),
                OlCard(
                  child: Column(
                    children: [for (final x in s.byTherapist) OlMeterRow(label: x.name, value: x.sessions, max: maxSessions)],
                  ),
                ),
              ],
              for (final a in s.alerts)
                if (a.count > 0)
                  OlBanner(
                    message: '${_alertLabel(a.kind)}: ${a.count}${a.amount == null ? '' : ' · ${Fmt.money(a.amount!)}'}',
                    tone: OlBannerTone.warn,
                  ),
            ];
          },
        ),
        const OlSectionHeader(title: 'Rincian'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final k in reportLabels.keys.where((k) => k != 'patients' && k != 'revenue'))
                Padding(
                  padding: const EdgeInsets.only(right: OlSpace.sm),
                  child: OlChip(label: reportLabels[k]!, small: true, selected: _report == k, onTap: () => setState(() => _report = k)),
                ),
            ],
          ),
        ),
        OlAsync<ReportTableV>(
          key: ValueKey((_report, _range)),
          load: () => api.report(_report, from: from, to: to),
          builder: (context, r, _) => [_Table(r)],
        ),
      ],
    );
  }
}

String _alertLabel(String kind) => switch (kind) {
  'inactive_patients' => 'Pasien tidak datang 30 hari',
  'receivables_over_7d' => 'Piutang lewat 7 hari',
  'cash_difference' => 'Selisih kas',
  'pending_approvals' => 'Menunggu persetujuan',
  _ => kind,
};

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => OlCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.olText.caption.copyWith(color: context.ol.muted)),
        Text(value, style: context.olText.title),
      ],
    ),
  );
}

class _Table extends StatelessWidget {
  const _Table(this.r);
  final ReportTableV r;

  String _cell(Object? v, String type) {
    if (v == null) return '-';
    return switch (type) {
      'money' => Fmt.money(v is num ? v : num.tryParse('$v') ?? 0),
      'percent' => '${v is num ? v.toStringAsFixed(1) : v}%',
      _ => '$v',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    if (r.rows.isEmpty) {
      return const OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Tidak ada data', message: 'Belum ada transaksi di periode ini.'));
    }
    return OlCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: t.caption.copyWith(color: c.muted, fontWeight: FontWeight.w600),
          dataTextStyle: t.body,
          columnSpacing: OlSpace.lg,
          columns: [
            for (final col in r.columns) DataColumn(label: Text(col.label), numeric: col.type == 'money' || col.type == 'number' || col.type == 'percent'),
          ],
          rows: [
            for (final row in r.rows) DataRow(cells: [for (final col in r.columns) DataCell(Text(_cell(row[col.key], col.type)))]),
            if (r.totals.isNotEmpty)
              DataRow(
                cells: [
                  for (final (i, col) in r.columns.indexed)
                    DataCell(Text(i == 0 ? 'Total' : r.totals.containsKey(col.key) ? _cell(r.totals[col.key], col.type) : '', style: t.bodyStrong)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
