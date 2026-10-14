import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// KS-15 Verifikasi transfer manual: bandingkan bukti dengan tagihan.
/// Staf yang mengunggah bukti tidak bisa memverifikasi transaksinya sendiri.
class VerifikasiTransferPage extends StatelessWidget {
  const VerifikasiTransferPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Verifikasi transfer',
    feature: 'Verifikasi transfer',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
