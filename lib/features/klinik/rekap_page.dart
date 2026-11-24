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
    return OlPageBody(
      header: const OlAppHeader(title: 'Rekap Data'),
      onRefresh: () async => setState(() => _gen++),
      children: [
        MonthSwitcher(
          month: _month,
          onChanged: (m) => setState(() => _month = m),
        ),
        OlButton.secondary(
          label: _exporting ? 'Menyiapkan Excel…' : 'Export Excel',
          icon: OlIcons.download,
          onPressed: _exporting ? null : _export,
        ),
        OlAsync<List<RekapRow>>(
          key: ValueKey('$_month-$_gen'),
          load: () => ref.read(klinikApiProvider).rekap(_month),
          builder: (context, rows, _) => [
            if (rows.isEmpty)
              const OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptySchedule,
                  title: 'Belum ada pemeriksaan',
                  message: 'Tidak ada data pemeriksaan pasien pada bulan ini.',
                ),
              )
            else ...[
              Text('${rows.length} pemeriksaan', style: t.caption),
              for (final (i, r) in rows.indexed)
                OlCard(
                  onTap: () => context.push(Routes.klinikDetail(r.pasienId)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${i + 1}. ${r.nama}',
                              style: t.bodyStrong,
                            ),
                          ),
                          Text(tgl(r.tanggal), style: t.caption),
                        ],
                      ),
                      Text(
                        [
                          nomorPasien(r.nomor),
                          genderLabel(r.gender),
                          'Lahir ${tgl(r.ttl)}',
                        ].join(' · '),
                        style: t.caption,
                      ),
                      Text(r.alamat ?? '-', style: t.caption),
                      const SizedBox(height: OlSpace.xs),
                      LabelValue('Keluhan', r.keluhan),
                      LabelValue('Diagnosa', r.analisa),
                      LabelValue('Treatment', r.treatment),
                      LabelValue('Bagian yang ditangani', r.bagianPenenang),
                      LabelValue('Terapis', r.terapis),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
