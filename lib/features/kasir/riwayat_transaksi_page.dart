import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// KS-13 Riwayat transaksi & detail: per hari, filter metode/status/penagih.
class RiwayatTransaksiPage extends StatelessWidget {
  const RiwayatTransaksiPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Riwayat transaksi',
    feature: 'Riwayat transaksi',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
