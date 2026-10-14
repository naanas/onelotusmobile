import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// KS-12 Jual paket / membership. Belum tersambung ke server (lihat [OlUnavailablePage]).
class JualPaketPage extends StatelessWidget {
  const JualPaketPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Jual paket',
    feature: 'Penjualan paket',
    waitingFor:
        'aturan paket & membership dari workshop (§16) dan modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
