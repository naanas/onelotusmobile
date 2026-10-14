import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-16 Poin Lotus & referral: saldo, kode referral (salin/bagikan), riwayat poin.
class PoinPasienPage extends StatelessWidget {
  const PoinPasienPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Poin & referral',
    feature: 'Poin & referral',
    waitingFor: 'aturan poin dari workshop (§16 no. 14)',
  );
}
