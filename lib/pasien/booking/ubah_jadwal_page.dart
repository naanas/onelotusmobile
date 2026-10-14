import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-11 Ubah / batalkan jadwal sendiri. Belum tersambung ke server (lihat [OlUnavailablePage]).
class UbahJadwalPage extends StatelessWidget {
  const UbahJadwalPage({super.key, this.pastDeadline = false});

  final bool pastDeadline;

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Ubah jadwal',
    feature: 'Ubah / batalkan jadwal sendiri',
    waitingFor:
        'aturan batas ubah jadwal dari workshop (§16 no. 8). Untuk sementara, hubungi klinik',
  );
}
