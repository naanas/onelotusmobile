import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/models.dart';
import '../../../router/routes.dart';
import '../../../ui/ui.dart';
import '../../shared/patient_list.dart';

/// TR-06 Pasien saya (tab Pasien terapis): pasien yang pernah ditangani terapis login
/// (`GET /v1/patients?scope=mine`), penanda belum kembali >30 hari & paket hampir habis.
class PasienSayaPage extends StatelessWidget {
  const PasienSayaPage({super.key});

  @override
  Widget build(BuildContext context) => OlPageBody(
    header: const OlAppHeader(title: 'Pasien saya'),
    children: [
      PatientList(
        mine: true,
        hint: 'Cari nama atau #nomor',
        filters: const [
          PatientListFilter('Semua', PatientFilter()),
          PatientListFilter(
            'Belum kembali >30 hari',
            PatientFilter(away: true),
          ),
          PatientListFilter('Punya paket', PatientFilter(hasPackage: true)),
        ],
        onTap: (p) => context.push(Routes.terapisPasienDetail(p.id)),
      ),
    ],
  );
}
