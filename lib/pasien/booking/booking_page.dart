import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-08 Booking (tab Booking): layanan → lokasi & terapis → waktu + ringkasan
/// → terkirim, menunggu konfirmasi front desk (§5.13).
class BookingPage extends StatelessWidget {
  const BookingPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailableTab(
    title: 'Booking',
    feature: 'Booking dari aplikasi',
    waitingFor:
        'aturan booking pasien dari workshop (§16 no. 11, 13, 18). Untuk sementara, hubungi klinik lewat WhatsApp',
  );
}
