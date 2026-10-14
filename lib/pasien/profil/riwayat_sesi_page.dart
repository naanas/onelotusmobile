import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-12 Riwayat sesi versi pasien: area, nyeri, perawatan, saran —
/// tanpa catatan internal terapis (§5.13, §10).
class RiwayatSesiPage extends StatelessWidget {
  const RiwayatSesiPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Riwayat sesi',
    feature: 'Riwayat sesi versi pasien',
    waitingFor: 'endpoint ringkasan rekam sesi untuk pasien',
  );
}
