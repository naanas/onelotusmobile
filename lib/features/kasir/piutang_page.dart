import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// KS-18 Piutang (tagihan belum lunas): pilih pasien → kirim link bayar massal / lunasi.
/// Pengingat sejenis maksimal 1 kali per 7 hari per pasien.
class PiutangPage extends StatelessWidget {
  const PiutangPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Piutang',
    feature: 'Piutang',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
