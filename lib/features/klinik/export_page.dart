import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'k_ui.dart';
import 'widgets.dart';

/// Export Excel (Laravel /export): pilih bulan → unduh `MM-YYYY_data_pasien.xlsx`.
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  static const _kolom = [
    'Nama',
    'Nomor pasien',
    'Tanggal lahir',
    'Nomor telepon',
    'Alamat',
    'BB',
    'TB',
    'Jenis kelamin',
    'Instansi',
    'Hobi',
    'Keluhan',
    'Analisa',
    'Treatment',
    'Bagian penanganan',
    'Kesimpulan',
    'Terapis',
    'Tanggal',
  ];

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    await exportExcel(context, ref, _month);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authProvider.select((s) => s.user?.isAdmin ?? false));
    return OlDetailScaffold(
      title: 'Export Excel',
      foot: [OlButton(label: 'Download', icon: OlIcons.download, loading: _busy, onPressed: _export)],
      children: [
        KHero(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: const OlIcon(OlIcons.download, size: 28, color: Colors.white),
              ),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data pemeriksaan', style: context.olText.title.copyWith(color: Colors.white, fontSize: 19)),
                    const SizedBox(height: 4),
                    Text(
                      'File Excel (.xlsx) satu bulan, siap dibagikan atau disimpan.',
                      style: context.olText.caption.copyWith(color: Colors.white.withValues(alpha: .78), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const OlSectionHeader(title: 'Pilih bulan'),
        MonthSwitcher(month: _month, onChanged: (m) => setState(() => _month = m)),
        KFormSection(
          icon: OlIcons.report,
          title: 'Kolom di file',
          subtitle: admin ? '${_kolom.length} kolom' : 'Nomor telepon dikosongkan (khusus admin)',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in _kolom)
                  if (admin || k != 'Nomor telepon')
                    KPill(k, tone: KPillTone.brand)
                  else
                    const KPill('Nomor telepon', icon: OlIcons.lock, tone: KPillTone.muted),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
