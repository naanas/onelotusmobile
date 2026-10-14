import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// UM-09 Pusat notifikasi: Semua / Belum dibaca, tandai semua dibaca, ketuk → layar terkait.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Notifikasi',
    feature: 'Notifikasi',
    waitingFor: 'layanan notifikasi (push & WhatsApp)',
  );
}
