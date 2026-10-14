import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-20 Kirim pengingat massal (WhatsApp): segmen, template, pratinjau,
/// daftar penerima. Pasien yang menolak promo otomatis dikecualikan;
/// pengingat sejenis maks 1×/7 hari per pasien.
class PengingatPage extends StatelessWidget {
  const PengingatPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Kirim pengingat',
    feature: 'Pengingat massal',
    waitingFor: 'layanan WhatsApp (penyedia belum dipilih)',
  );
}
