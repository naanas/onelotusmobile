import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// KS-10 Pembayaran: QRIS (KS-10b), Tunai + CashCalculator (KS-10a), Transfer/VA,
/// Pakai paket → pembayaran gabungan (KS-10c), Poin.
class BayarPage extends StatelessWidget {
  const BayarPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Pembayaran',
    feature: 'Pembayaran',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
