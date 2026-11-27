import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'k_ui.dart';
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

  /// Rata-rata pemeriksaan per hari yang sudah lewat di bulan ini.
  int _perHari(int total) {
    final now = DateTime.now();
    final last = DateTime(_month.year, _month.month + 1, 0).day;
    final days = (_month.year == now.year && _month.month == now.month) ? now.day : last;
    return days == 0 ? 0 : (total / days).round();
  }

  static const _hariNama = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  String _hari(DateTime? d, String fallback) {
    if (d == null) return fallback;
    final r = relatif(d);
    return r == 'Hari ini' || r == 'Kemarin' ? '$r · $fallback' : '${_hariNama[d.weekday - 1]}, $fallback';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
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
              else
                KHero(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan ${monthFmt.format(_month)}',
                        style: t.caption.copyWith(
                          color: Colors.white.withValues(alpha: .8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: OlSpace.md),
                      KStatRow(
                        light: true,
                        children: [
                          KStat(value: p.loadedOnce ? p.total : null, label: 'Pemeriksaan', light: true),
                          KStat(value: p.loadedOnce ? pasien : null, label: 'Pasien', light: true),
                          KStat(value: p.loadedOnce ? _perHari(p.total) : null, label: 'Per hari', light: true),
                        ],
                      ),
                      const SizedBox(height: OlSpace.lg),
                      KGlassButton(
                        icon: OlIcons.download,
                        label: _exporting ? 'Menyiapkan Excel…' : 'Export Excel',
                        busy: _exporting,
                        onTap: _export,
                      ),
                    ],
                  ),
                ),
              for (final e in byDay.entries) ...[
                Row(
                  children: [
                    Expanded(child: OlSectionHeader(title: _hari(e.value.first.tanggal, e.key))),
                    KPill('${e.value.length} pasien', tone: KPillTone.brand),
                  ],
                ),
                Column(
                  children: [
                    for (final (i, r) in e.value.indexed)
                      KTimelineTile(
                        last: i == e.value.length - 1,
                        child: _RekapCard(row: r),
                      ),
                  ],
                ),
              ],
              PagerFooter(pager: p, endLabel: 'Semua ${p.total} pemeriksaan sudah tampil'),
              if (rows.isNotEmpty)
                Text('${rows.length} dari ${p.total} ditampilkan', style: t.caption, textAlign: TextAlign.center),
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
    final u = umur(r.ttl);
    return OlCard(
      onTap: () => context.push(Routes.klinikDetail(r.pasienId)),
      semanticLabel: 'Pemeriksaan ${r.nama}',
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KAvatar(name: r.nama, size: 40),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.nama, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      [nomorPasien(r.nomor), genderLabel(r.gender), if (u != null) '$u th'].join(' · '),
                      style: t.caption,
                    ),
                  ],
                ),
              ),
              OlIcon(OlIcons.chevronRight, size: 18, color: c.faint),
            ],
          ),
          if (r.keluhan != null) ...[const SizedBox(height: 10), KQuote(r.keluhan!, maxLines: 2)],
          KTextBlock(icon: OlIcons.report, label: 'Diagnosa', value: r.analisa),
          KTextBlock(
            icon: OlIcons.hands,
            label: 'Treatment',
            value: [r.treatment, if (r.bagianPenenang != null) '(${r.bagianPenenang})'].whereType<String>().join(' '),
          ),
          if (r.terapis != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: KPill(r.terapis!, icon: OlIcons.user, tone: KPillTone.brand),
            ),
          ],
        ],
      ),
    );
  }
}
