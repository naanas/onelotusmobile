import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// PS-19 Alamat home visit tersimpan + tambah alamat (titik peta wajib).
/// Jangkauan home visit dihitung dari cabang (radius dari OW-17).
class AlamatPage extends StatelessWidget {
  const AlamatPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Alamat tersimpan',
    feature: 'Alamat tersimpan',
    waitingFor: 'layanan home visit pasien (booking dari aplikasi)',
  );
}
