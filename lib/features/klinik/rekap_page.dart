import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'klinik_api.dart';
import 'klinik_models.dart';
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

class _RekapPageState extends ConsumerState<RekapPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _exporting = false;
  int _gen = 0;

  Future<void> _export() async {
    setState(() => _exporting = true);
    await exportExcel(context, ref, _month);
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    return OlPageBody(
      pinnedHeader: true,
      header: const OlAppHeader(title: 'Rekap Data'),
      onRefresh: () async => setState(() => _gen++),
      children: [
        MonthSwitcher(
          month: _month,
          onChanged: (m) => setState(() => _month = m),
        ),
        OlAsync<List<RekapRow>>(
          key: ValueKey('$_month-$_gen'),
          load: () => ref.read(klinikApiProvider).rekap(_month),
          builder: (context, rows, _) {
            if (rows.isEmpty) {
              return const [
                OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptySchedule,
                    title: 'Belum ada pemeriksaan',
                    message: 'Tidak ada data pemeriksaan pasien pada bulan ini.',
                  ),
                ),
              ];
            }
            final pasien = {for (final r in rows) r.pasienId}.length;
            // Kelompok per tanggal, terbaru dulu (seperti daftar jadwal pasien).
            final byDay = <String, List<RekapRow>>{};
            for (final r in rows.reversed) {
              byDay.putIfAbsent(tgl(r.tanggal), () => []).add(r);
            }
            return [
              OlCard(
                child: Row(
                  children: [
                    Expanded(child: _Stat(label: 'Pemeriksaan', value: '${rows.length}')),
                    Container(width: 1, height: 36, color: c.line),
                    Expanded(child: _Stat(label: 'Pasien', value: '$pasien')),
                  ],
                ),
              ),
              OlButton.secondary(
                label: _exporting ? 'Menyiapkan Excel…' : 'Export Excel',
                icon: OlIcons.download,
                onPressed: _exporting ? null : _export,
              ),
              for (final e in byDay.entries) ...[
                OlSectionHeader(title: '${e.key} · ${e.value.length} pemeriksaan'),
                for (final r in e.value)
                  OlCard(
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
                  ),
              ],
            ];
          },
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return Column(
      children: [
        Text(value, style: t.heading.copyWith(color: context.ol.brand)),
        Text(label, style: t.caption),
      ],
    );
  }
}
