import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-15 Struk digital pasien: bagikan / simpan PDF.
class StrukPasienPage extends StatelessWidget {
  const StrukPasienPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Struk',
    feature: 'Struk',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
