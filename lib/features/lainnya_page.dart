import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/auth.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../ui/ui.dart';

/// Lainnya: akun yang sedang masuk, Export Excel, User Management (khusus admin), Keluar.
class LainnyaPage extends ConsumerWidget {
  const LainnyaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.olText;
    final c = context.ol;
    final user = ref.watch(authProvider.select((s) => s.user));
    final admin = user?.isAdmin ?? false;
    return OlPageBody(
      header: const OlAppHeader(title: 'Lainnya'),
      children: [
        OlCard(
          child: Row(
            children: [
              OlAvatar(name: user?.name ?? '-'),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? '-', style: t.bodyStrong),
                    Text(
                      '${user?.username ?? ''} · ${user?.role.label ?? ''}',
                      style: t.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        OlCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              OlListItem(
                leading: OlIcon(OlIcons.download, color: c.brand),
                title: 'Export Excel',
                subtitle: 'Unduh data pemeriksaan per bulan',
                showChevron: true,
                onTap: () => context.push(Routes.export),
              ),
              if (admin)
                OlListItem(
                  leading: OlIcon(OlIcons.users, color: c.brand),
                  title: 'User Management',
                  subtitle: 'Tambah user, ubah password, hapus user',
                  showChevron: true,
                  divider: false,
                  onTap: () => context.push(Routes.user),
                ),
            ],
          ),
        ),
        OlButton(
          label: 'Keluar',
          icon: OlIcons.logout,
          variant: OlButtonVariant.dangerSecondary,
          onPressed: () async {
            final ok = await context.feedback.confirm(
              const ConfirmSpec(
                title: 'Keluar dari aplikasi?',
                message: '',
                confirmLabel: 'Keluar',
              ),
            );
            if (ok) await ref.read(authProvider.notifier).logout();
          },
        ),
        Center(child: Text('One Lotus v$kAppVersion', style: t.caption)),
      ],
    );
  }
}
