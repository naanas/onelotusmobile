import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-12 Voucher & promo: daftar voucher + pemakaian, buat voucher baru.
class VoucherPage extends StatelessWidget {
  const VoucherPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Voucher & promo',
    feature: 'Voucher & promo',
    waitingFor: 'aturan voucher & diskon dari workshop (§16 no. 14)',
  );
}
