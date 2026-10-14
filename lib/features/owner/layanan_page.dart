import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// OW-09 Layanan & harga: daftar layanan aktif cabang dari `GET /v1/services` (baca-saja).
/// Ubah harga, harga member, biaya per titik, dan riwayat harga menunggu endpoint kelola layanan (Fase 2).
class LayananPage extends ConsumerWidget {
  const LayananPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(authProvider.select((a) => a.activeBranch));
    return OlDetailScaffold(
      title: 'Layanan & harga',
      context_: branch?.name,
      children: [
        OlAsync<List<Service>>(
          load: () => ref.read(oneLotusApiProvider).services(branch!.id),
          builder: (context, list, _) => [
            if (list.isEmpty)
              const OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptyInbox,
                  title: 'Belum ada layanan',
                  message: 'Tambahkan layanan di tabel mobile.services.',
                ),
              )
            else
              OlCard(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                child: Column(
                  children: [
                    for (final (i, s) in list.indexed)
                      OlListItem(
                        title: s.name,
                        subtitle: '${s.durationMin} mnt',
                        trailing: Text(
                          Fmt.money(s.price),
                          style: context.olText.mono.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        divider: i < list.length - 1,
                      ),
                  ],
                ),
              ),
            Text(
              'Mengubah harga dari aplikasi menunggu fitur kelola layanan.',
              style: context.olText.body.copyWith(color: context.ol.muted),
            ),
          ],
        ),
      ],
    );
  }
}
