import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-16 Pengumuman staf: judul, isi, penerima (peran × cabang), kirim sekarang
/// atau dijadwalkan. Muncul di pusat notifikasi staf.
class PengumumanPage extends StatelessWidget {
  const PengumumanPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Pengumuman',
    feature: 'Pengumuman',
    waitingFor: 'layanan notifikasi (push & WhatsApp)',
  );
}
