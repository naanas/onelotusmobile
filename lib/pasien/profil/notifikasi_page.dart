import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-17 Notifikasi pasien + pengaturan per jenis (jadwal, latihan, promo).
class NotifikasiPasienPage extends StatelessWidget {
  const NotifikasiPasienPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Notifikasi',
    feature: 'Notifikasi',
    waitingFor: 'layanan notifikasi (push & WhatsApp)',
  );
}
