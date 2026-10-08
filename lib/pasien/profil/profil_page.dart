import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../demo_data.dart';
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
    final phone = ref.watch(pasienSessionProvider.select((s) => s.phone));

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
              const OlAvatar(name: 'Rina Setiawati', large: true),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rina Setiawati', style: t.heading),
                    const SizedBox(height: 2),
                    Text(
                      '#0387 · ${phone.isEmpty ? '0812 3456 7890' : phone}',
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
            trailing: const OlTag('1 mendatang', tone: OlTagTone.outline),
            onTap: () => context.push(PRoutes.jadwal),
          ),
          OlListItem(
            title: 'Riwayat sesi',
            showChevron: true,
            onTap: () => context.push(PRoutes.riwayat),
          ),
          OlListItem(
            title: 'Paket & pembayaran',
            trailing: const OlTag('1 belum lunas', tone: OlTagTone.warn),
            onTap: () => context.push(PRoutes.paket),
          ),
          OlListItem(
            title: 'Poin & referral',
            trailing: Text(
              '$demoPoints poin',
              style: t.mono.copyWith(
                fontWeight: FontWeight.w700,
                color: c.warn,
              ),
            ),
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
            trailing: Text('2 alamat', style: t.body.copyWith(color: c.muted)),
            onTap: () => context.push(PRoutes.alamat),
          ),
          OlListItem(
            title: 'Persetujuan data',
            showChevron: true,
            onTap: () => context.push(PRoutes.kebijakan),
          ),
          OlListItem(
            title: 'Bantuan & kontak klinik',
            showChevron: true,
            onTap: () => context.feedback.sheet<void>(
              title: 'Bantuan & kontak klinik',
              message:
                  'Klinik Pusat Malang · Jl. Soekarno-Hatta No. 9\nBuka Senin–Jumat 08.00–20.00, Sabtu 08.00–17.00',
              actions: const [
                SheetAction('Chat WhatsApp klinik', null),
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
