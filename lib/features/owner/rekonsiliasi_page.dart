import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-19 Rekonsiliasi gateway (QRIS & VA): total sistem vs settlement per hari,
/// selisih yang perlu dicek.
class RekonsiliasiPage extends StatelessWidget {
  const RekonsiliasiPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Rekonsiliasi',
    feature: 'Rekonsiliasi gateway',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
