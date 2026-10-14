import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// KS-09 Tagihan (tab Kasir): MoneyRow dengan urutan potongan §6.4.4, item tambahan,
/// voucher & diskon (manual wajib alasan), UpsellCard paket, bayar.
class TagihanPage extends StatelessWidget {
  const TagihanPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailableTab(
    title: 'Kasir',
    feature: 'Tagihan & pembayaran',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
