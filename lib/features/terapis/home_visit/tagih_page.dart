import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// TR-10 Tagih di lokasi: tagihan ringkas, QRIS / tunai / paket / link bayar.
/// Terapis tidak bisa menambah diskon atau mengubah harga.
class TagihPage extends StatelessWidget {
  const TagihPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Tagih di lokasi',
    feature: 'Penagihan di lokasi',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
