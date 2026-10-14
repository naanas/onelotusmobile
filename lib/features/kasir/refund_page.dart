import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// KS-14 Refund / batal transaksi (§6.4.6): item → alasan → metode → dampak otomatis → konfirmasi.
/// Di atas batas tertentu perlu persetujuan owner (batas: workshop §16 no. 9).
class RefundPage extends StatelessWidget {
  const RefundPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Refund / batal',
    feature: 'Refund',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
