import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../ui/ui.dart';
import '../shared/patient_list.dart';

/// OW-03 Pasien (tab Pasien owner): sama dengan KS-03 + filter arsip; detail pasien membuka
/// layar kasir (owner boleh) dengan aksi pulihkan dari arsip.
class PasienOwnerPage extends StatelessWidget {
  const PasienOwnerPage({super.key});

  @override
  Widget build(BuildContext context) => OlPageBody(
    header: OlAppHeader(
      title: 'Pasien',
      actions: [
        OlButton(
          label: '+ Tambah',
          small: true,
          expand: false,
          onPressed: () => context.push(Routes.kasirPasienForm),
        ),
      ],
    ),
    children: [
      PatientList(
        filters: const [
          PatientListFilter('Aktif', PatientFilter()),
          PatientListFilter('Punya paket', PatientFilter(hasPackage: true)),
          PatientListFilter('Belum lunas', PatientFilter(unpaid: true)),
          PatientListFilter('>30 hari', PatientFilter(away: true)),
          PatientListFilter('Arsip', PatientFilter(archived: true)),
        ],
        onTap: (p) => context.push(Routes.kasirPasienDetail(p.id)),
      ),
    ],
  );
}
