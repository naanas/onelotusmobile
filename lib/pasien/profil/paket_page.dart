import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-13 Paket & pembayaran: paket aktif + sisa kuota, tagihan belum lunas,
/// riwayat pembayaran & refund (ketuk → struk).
class PaketPage extends StatelessWidget {
  const PaketPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Paket & pembayaran',
    feature: 'Paket & pembayaran',
    waitingFor:
        'aturan paket & membership dari workshop (§16) dan modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
