import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../ui/ui.dart';
import '../shared/patient_list.dart';

/// UM-10 Pencarian global: pasien (nama/nomor/4 digit HP) dari `GET /v1/patients`.
/// Terapis membuka detail pasien versi terapis (TR-05); kasir & owner versi kasir (KS-05).
class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider.select((a) => a.activeRole));
    return OlDetailScaffold(
      title: 'Cari pasien',
      children: [
        PatientList(
          onTap: (p) => context.push(
            role == Role.terapis
                ? Routes.terapisPasienDetail(p.id)
                : Routes.kasirPasienDetail(p.id),
          ),
        ),
      ],
    );
  }
}
