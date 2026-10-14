import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-04 Laporan (tab Laporan owner): omzet per hari & metode, layanan,
/// terapis, retensi, home visit. Ekspor ke OW-05.
class LaporanPage extends StatelessWidget {
  const LaporanPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailableTab(
    title: 'Laporan',
    feature: 'Laporan',
    waitingFor:
        'layanan laporan & ringkasan keuangan (bergantung modul pembayaran)',
  );
}
