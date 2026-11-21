import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth.dart';
import '../theme/app_theme.dart';
import '../ui/ui.dart';
import 'widgets.dart';

/// Export Excel (Laravel /export): pilih bulan → unduh `MM-YYYY_data_pasien.xlsx`.
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    await exportExcel(context, ref, _month);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authProvider.select((s) => s.isAdmin));
    return OlDetailScaffold(
      title: 'Export Excel',
      foot: [
        OlButton(
          label: 'Download',
          icon: OlIcons.download,
          loading: _busy,
          onPressed: _export,
        ),
      ],
      children: [
        Text(
          'Pilih bulan data pemeriksaan yang akan diexport.',
          style: context.olText.body,
        ),
        MonthSwitcher(
          month: _month,
          onChanged: (m) => setState(() => _month = m),
        ),
        OlBanner(
          tone: OlBannerTone.info,
          icon: OlIcons.info,
          message: admin
              ? 'Kolom: nama, nomor pasien, tanggal lahir, nomor telepon, alamat, BB, TB, jenis kelamin, instansi, '
                    'hobi, keluhan, analisa, treatment, bagian penanganan, kesimpulan, terapis, tanggal.'
              : 'Kolom nomor telepon dikosongkan karena hanya admin yang boleh melihatnya.',
        ),
      ],
    );
  }
}
