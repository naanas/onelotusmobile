import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-09 Pembayaran online (§6.4.2): tagihan belum lunas → pilih metode gateway.
/// Status lunas hanya dari konfirmasi sistem (webhook), bukan dari layar ini.
class BayarPage extends StatelessWidget {
  const BayarPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Pembayaran',
    feature: 'Pembayaran online',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
