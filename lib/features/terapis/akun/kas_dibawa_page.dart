import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// TR-11 Kas dibawa & serah terima ke kasir (§6.4.7).
class KasDibawaPage extends StatelessWidget {
  const KasDibawaPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Kas dibawa',
    feature: 'Kas dibawa',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
