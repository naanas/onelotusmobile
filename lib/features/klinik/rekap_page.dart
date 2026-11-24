import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'klinik_api.dart';
import 'klinik_models.dart';
import 'pager.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'widgets.dart';

/// Rekap Data (Laravel /pasien?limit=YYYY-MM): semua pemeriksaan pada bulan terpilih.
class RekapPage extends ConsumerStatefulWidget {
  const RekapPage({super.key});

  @override
  ConsumerState<RekapPage> createState() => _RekapPageState();
}

class _RekapPageState extends ConsumerState<RekapPage> with VisibleReload {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _exporting = false;
  late Pager<RekapRow> _pager = _newPager();

  Pager<RekapRow> _newPager() =>
      Pager<RekapRow>((page) => ref.read(klinikApiProvider).rekap(_month, page: page))..reload();

  void _setMonth(DateTime m) {
    final old = _pager;
    setState(() {
      _month = m;
      _pager = _newPager();
    });
    old.dispose();
  }

  @override
  void onVisibleAgain() => _pager.refresh();

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    await exportExcel(context, ref, _month);
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    return InfiniteScroll(
      onEnd: _pager.more,
      child: ListenableBuilder(
        listenable: _pager,
        builder: (context, _) {
          final p = _pager;
          final rows = p.items;
          final meta = p.first?.meta ?? const {};
          final pasien = (meta['total_pasien'] as num?)?.toInt() ?? 0;
          // Kelompok per tanggal (data sudah urut terbaru dulu dari server).
          final byDay = <String, List<RekapRow>>{};
          for (final r in rows) {
            byDay.putIfAbsent(tgl(r.tanggal), () => []).add(r);
          }
          return OlPageBody(
            pinnedHeader: true,
            backToTop: true,
            header: const OlAppHeader(title: 'Rekap Data'),
            onRefresh: () {
              ref.read(klinikApiProvider).cache.expire('/v1/klinik/rekap');
              return _pager.reload();
            },
            children: [
              MonthSwitcher(month: _month, onChanged: _setMonth),
              if (p.loadedOnce && p.total == 0 && p.error == null)
                const OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptySchedule,
                    title: 'Belum ada pemeriksaan',
                    message: 'Tidak ada data pemeriksaan pasien pada bulan ini.',
                  ),
                )
              else if (p.loadedOnce) ...[
                OlCard(
                  child: Row(
                    children: [
                      Expanded(child: _Stat(label: 'Pemeriksaan', value: p.total)),
                      Container(width: 1, height: 36, color: c.line),
                      Expanded(child: _Stat(label: 'Pasien', value: pasien)),
                    ],
                  ),
                ),
                OlButton.secondary(
                  label: _exporting ? 'Menyiapkan Excel…' : 'Export Excel',
                  icon: OlIcons.download,
                  onPressed: _exporting ? null : _export,
                ),
              ],
              for (final e in byDay.entries) ...[
                OlSectionHeader(title: e.key),
                for (final r in e.value) _RekapCard(row: r),
              ],
              PagerFooter(pager: p, endLabel: 'Semua ${p.total} pemeriksaan sudah tampil'),
              if (rows.isNotEmpty) Text('${rows.length} dari ${p.total} ditampilkan', style: t.caption, textAlign: TextAlign.center),
            ],
          );
        },
      ),
    );
  }
}

class _RekapCard extends StatelessWidget {
  const _RekapCard({required this.row});
  final RekapRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    final r = row;
    return OlCard(
      onTap: () => context.push(Routes.klinikDetail(r.pasienId)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OlAvatar(name: r.nama),
          const SizedBox(width: OlSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.nama, style: t.bodyStrong),
                Text(
                  [nomorPasien(r.nomor), genderLabel(r.gender), 'Lahir ${tgl(r.ttl)}'].join(' · '),
                  style: t.caption,
                ),
                const SizedBox(height: OlSpace.xs),
                LabelValue('Keluhan', r.keluhan),
                LabelValue('Diagnosa', r.analisa),
                LabelValue('Treatment', r.treatment),
                LabelValue('Bagian yang ditangani', r.bagianPenenang),
                LabelValue('Terapis', r.terapis),
              ],
            ),
          ),
          OlIcon(OlIcons.chevronRight, color: c.muted),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return Column(
      children: [
        OlCountUp(value, style: t.heading.copyWith(color: context.ol.brand, fontSize: 22)),
        Text(label, style: t.caption),
      ],
    );
  }
}
