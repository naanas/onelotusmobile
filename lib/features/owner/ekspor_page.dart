import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-05 Ekspor laporan: jenis, rentang tanggal, cabang, format. Data kontak
/// pasien hanya bila diaktifkan + alasan (UU PDP). Setiap ekspor masuk audit log.
class EksporPage extends StatelessWidget {
  const EksporPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Ekspor',
    feature: 'Ekspor data',
    waitingFor:
        'layanan laporan & ringkasan keuangan (bergantung modul pembayaran)',
  );
}
