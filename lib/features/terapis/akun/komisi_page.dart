import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// TR-12 Komisi saya: estimasi sampai disetujui owner. Belum tersambung ke server (lihat [OlUnavailablePage]).
class KomisiPage extends StatelessWidget {
  const KomisiPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Komisi saya',
    feature: 'Komisi',
    waitingFor: 'aturan komisi dari workshop (§16 no. 2)',
  );
}
