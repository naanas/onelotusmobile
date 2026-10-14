import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-15 Pustaka latihan: daftar latihan per area, setujui usulan terapis,
/// tambah latihan dengan video.
class PustakaPage extends StatelessWidget {
  const PustakaPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Pustaka latihan',
    feature: 'Pustaka latihan',
    waitingFor:
        'layanan program latihan rumah (pustaka latihan & kirim program)',
  );
}
