import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/auth/auth_controller.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Lainnya (gaya sama dengan Profil pasien): akun yang sedang masuk, Export Excel,
/// User Management (khusus admin), ubah password, bantuan, keluar.
class LainnyaPage extends ConsumerWidget {
  const LainnyaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.olText;
    final c = context.ol;
    final user = ref.watch(authProvider.select((s) => s.user));
    final branch = ref.watch(authProvider.select((s) => s.activeBranch));
    final admin = user?.isAdmin ?? false;

    Widget group(List<OlListItem> items) => OlCard(
      padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
      child: Column(
        children: [
          for (final (i, it) in items.indexed)
            i == items.length - 1 ? it.withoutDivider() : it,
        ],
      ),
    );

    Widget icon(OlIconData i) => OlIcon(i, color: c.brand);

    Future<void> logout() async {
      final ok = await context.feedback.confirm(
        const ConfirmSpec(
          title: 'Keluar dari aplikasi?',
          message: 'Masuk lagi dengan username & password.',
          confirmLabel: 'Keluar',
          danger: false,
        ),
      );
      if (ok) await ref.read(authProvider.notifier).logout();
    }

    return OlPageBody(
      pinnedHeader: true,
      header: const OlAppHeader(title: 'Lainnya'),
      children: [
        OlCard(
          child: Row(
            children: [
              OlAvatar(name: user?.name ?? '-', large: true),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? '-', style: t.heading),
                    const SizedBox(height: 2),
                    Text(
                      '@${user?.username ?? ''}',
                      style: t.mono.copyWith(fontSize: 13.5, color: c.muted),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        OlTag(admin ? 'Admin' : 'Terapis', tone: admin ? OlTagTone.fill : OlTagTone.brand),
                        if (branch != null) OlTag(branch.name, tone: OlTagTone.outline),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const OlSectionHeader(title: 'Data'),
        group([
          OlListItem(
            leading: icon(OlIcons.download),
            title: 'Export Excel',
            subtitle: 'Unduh data pemeriksaan per bulan',
            showChevron: true,
            onTap: () => context.push(Routes.klinikExport),
          ),
          if (admin)
            OlListItem(
              leading: icon(OlIcons.users),
              title: 'User Management',
              subtitle: 'Tambah user, ubah password, hapus user',
              showChevron: true,
              onTap: () => context.push(Routes.klinikUser),
            ),
        ]),
        const OlSectionHeader(title: 'Akun'),
        group([
          OlListItem(
            leading: icon(OlIcons.lock),
            title: 'Ubah password saya',
            showChevron: true,
            onTap: () => context.push(Routes.changePassword),
          ),
          OlListItem(
            leading: icon(OlIcons.info),
            title: 'Bantuan',
            showChevron: true,
            onTap: () => context.push(Routes.help),
          ),
        ]),
        OlButton.secondary(label: 'Keluar', icon: OlIcons.logout, onPressed: logout),
        Center(child: Text('One Lotus v$kAppVersion', style: t.caption)),
      ],
    );
  }
}
