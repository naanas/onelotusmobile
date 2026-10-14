import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-14 Beli / perpanjang paket via gateway. Poin opsional sebagai potongan.
class BeliPaketPage extends StatelessWidget {
  const BeliPaketPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Beli paket',
    feature: 'Pembelian paket',
    waitingFor:
        'aturan paket & membership dari workshop (§16) dan modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
