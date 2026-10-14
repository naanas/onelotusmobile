import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-06 Program latihan (tab Latihan): kepatuhan minggu ini, latihan hari ini
/// dengan video & centang, pengingat harian.
class LatihanPage extends StatelessWidget {
  const LatihanPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailableTab(
    title: 'Latihan',
    feature: 'Program latihan',
    waitingFor:
        'layanan program latihan rumah (pustaka latihan & kirim program)',
  );
}
