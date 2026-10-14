import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// KS-11 Konfirmasi pembayaran & struk (§6.4.5): layar sukses, bukan toast.
/// Struk tidak memuat catatan medis.
class StrukPage extends StatelessWidget {
  const StrukPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Struk',
    feature: 'Struk pembayaran',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
