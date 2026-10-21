import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';
import '../pasien_session.dart';

/// PS-18 Profil (tab Profil): data diri, pintasan jadwal/riwayat/paket/poin,
/// alamat, persetujuan data, bantuan, keluar, hapus akun.
class ProfilPage extends ConsumerWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ol;
    final t = context.olText;
    final account = ref.watch(pasienSessionProvider.select((s) => s.account));
    final patient = account?.patient;

    Widget group(List<OlListItem> items) => OlCard(
      padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
      child: Column(
        children: [
          for (final (i, it) in items.indexed)
            i == items.length - 1 ? it.withoutDivider() : it,
        ],
      ),
    );

    Future<void> logout() async {
      final ok = await context.feedback.confirm(
        const ConfirmSpec(
          title: 'Keluar dari aplikasi?',
          message:
              'Data Anda tetap tersimpan di klinik. Masuk lagi dengan nomor HP & kode WhatsApp.',
          confirmLabel: 'Keluar',
          danger: false,
        ),
      );
      if (ok) ref.read(pasienSessionProvider.notifier).logout();
    }

    return OlPageBody(
      header: const OlAppHeader(title: 'Profil'),
      children: [
        OlCard(
          child: Row(
            children: [
              OlAvatar(name: patient?.name ?? '-', large: true),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient?.name ?? '-', style: t.heading),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (patient != null) Fmt.patientNo(patient.number),
                        ?account?.phoneDisplay,
                      ].join(' · '),
                      style: t.mono.copyWith(fontSize: 13.5, color: c.muted),
                    ),
                  ],
                ),
              ),
              OlButton.secondary(
                label: 'Edit',
                small: true,
                expand: false,
                onPressed: () => context.feedback.info(
                  'Ubah nama & tanggal lahir lewat klinik agar rekam medis tetap cocok.',
                ),
              ),
            ],
          ),
        ),
        group([
          OlListItem(
            title: 'Jadwal saya',
            showChevron: true,
            onTap: () => context.push(PRoutes.jadwal),
          ),
          OlListItem(
            title: 'Riwayat sesi',
            showChevron: true,
            onTap: () => context.push(PRoutes.riwayat),
          ),
          OlListItem(
            title: 'Paket & pembayaran',
            showChevron: true,
            onTap: () => context.push(PRoutes.paket),
          ),
          OlListItem(
            title: 'Poin & referral',
            showChevron: true,
            onTap: () => context.push(PRoutes.poin),
          ),
          OlListItem(
            title: 'Notifikasi',
            showChevron: true,
            onTap: () => context.push(PRoutes.notifikasi),
          ),
        ]),
        group([
          OlListItem(
            title: 'Alamat tersimpan',
            showChevron: true,
            onTap: () => context.push(PRoutes.alamat),
          ),
          OlListItem(
            title: 'Bantuan & kontak klinik',
            showChevron: true,
            onTap: () => context.feedback.sheet<void>(
              title: 'Bantuan & kontak klinik',
              message:
                  'Untuk mengubah data diri atau jadwal, hubungi front desk One Lotus.',
              actions: const [
                SheetAction('Tutup', null, variant: OlButtonVariant.secondary),
              ],
            ),
          ),
        ]),
        Row(
          children: [
            Expanded(
              child: OlButton.secondary(label: 'Keluar', onPressed: logout),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: OlButton(
                label: 'Hapus akun',
                variant: OlButtonVariant.dangerText,
                onPressed: () => context.push(PRoutes.hapusAkun),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
