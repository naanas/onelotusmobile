import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-07 Detail latihan: video (bisa diunduh), langkah, batas nyeri,
/// catatan untuk terapis, "Selesai hari ini".
class DetailLatihanPage extends StatelessWidget {
  const DetailLatihanPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Latihan',
    feature: 'Detail latihan',
    waitingFor:
        'layanan program latihan rumah (pustaka latihan & kirim program)',
  );
}
