import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-07 Rekap komisi per bulan. Angka hanya contoh: aturan komisi menunggu
/// workshop mitra (spec §16) — layar ini tidak menghitung apa pun.
class RekapKomisiPage extends StatelessWidget {
  const RekapKomisiPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Rekap komisi',
    feature: 'Rekap komisi',
    waitingFor: 'aturan komisi dari workshop (§16 no. 2)',
  );
}
