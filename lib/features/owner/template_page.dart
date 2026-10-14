import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-14 Template pesan WhatsApp: isi dengan variabel, pratinjau, dan
/// pintasan ke pengaturan lain.
class TemplatePage extends StatelessWidget {
  const TemplatePage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Template pesan',
    feature: 'Template pesan',
    waitingFor: 'layanan WhatsApp (penyedia belum dipilih)',
  );
}
