import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// TR-13 Kirim program latihan (Fase 3): pustaka per area tubuh, atur set/repetisi, kirim ke app pasien.
class ProgramLatihanPage extends StatelessWidget {
  const ProgramLatihanPage({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Kirim program latihan',
    feature: 'Program latihan',
    waitingFor:
        'layanan program latihan rumah (pustaka latihan & kirim program)',
  );
}
