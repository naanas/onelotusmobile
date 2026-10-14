import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-10 Paket & membership. Perubahan tidak memengaruhi paket yang sudah terjual.
/// Aturan kuota/kedaluwarsa paket menunggu workshop mitra (spec §16) — hanya isian.
class PaketPage extends StatelessWidget {
  const PaketPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Paket & membership',
    feature: 'Pengaturan paket',
    waitingFor: 'aturan paket & membership dari workshop (§16)',
  );
}
