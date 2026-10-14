import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-11 Aturan komisi: komponen (persen/nominal), tanggal berlaku, pratinjau. Belum tersambung ke server (lihat [OlUnavailablePage]).
class AturanKomisiPage extends StatelessWidget {
  const AturanKomisiPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Aturan komisi',
    feature: 'Aturan komisi',
    waitingFor: 'aturan komisi dari workshop (§16 no. 2)',
  );
}
