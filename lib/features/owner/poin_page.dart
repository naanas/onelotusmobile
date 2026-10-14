import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-13 Poin Lotus & referral. Belum tersambung ke server (lihat [OlUnavailablePage]).
class PoinPage extends StatelessWidget {
  const PoinPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Poin & referral',
    feature: 'Poin & referral',
    waitingFor: 'aturan poin dari workshop (§16 no. 14)',
  );
}
