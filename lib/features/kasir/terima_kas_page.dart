import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// KS-16 Terima kas terapis (home visit, §6.4.7): hitung fisik vs tercatat sistem.
class TerimaKasPage extends StatelessWidget {
  const TerimaKasPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Terima kas terapis',
    feature: 'Serah terima kas',
    waitingFor:
        'modul pembayaran (payment gateway & aturan workshop §16 no. 9, 12–15)',
  );
}
