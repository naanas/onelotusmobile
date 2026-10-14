import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// KS-17 Tutup kas harian: sistem vs dihitung per metode, selisih wajib catatan,
/// QRIS yang masih menunggu harus diselesaikan dulu. Setelah ditutup, transaksi hari itu terkunci.
class TutupKasPage extends StatelessWidget {
  const TutupKasPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Tutup kas',
    feature: 'Tutup kas',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
