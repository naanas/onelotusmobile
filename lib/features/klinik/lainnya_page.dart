import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/auth/auth_controller.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'k_ui.dart';

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

    final purple = (const Color(0xFFEEEAFD), const Color(0xFF5B45C2));
    return OlPageBody(
      pinnedHeader: true,
      header: const OlAppHeader(title: 'Lainnya'),
      children: [
        KHero(
          child: Row(
            children: [
              KAvatar(name: user?.name ?? '-', size: 64, ring: true),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? '-', style: t.title.copyWith(color: Colors.white, fontSize: 20, height: 1.15)),
                    const SizedBox(height: 2),
                    Text(
                      '@${user?.username ?? ''}',
                      style: t.mono.copyWith(fontSize: 13, color: Colors.white.withValues(alpha: .75)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        KPill(
                          admin ? 'Admin' : 'Terapis',
                          icon: admin ? OlIcons.settings : OlIcons.hands,
                          tone: KPillTone.glass,
                        ),
                        if (branch != null) KPill(branch.name, icon: OlIcons.branch, tone: KPillTone.glass),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const OlSectionHeader(title: 'Data'),
        KMenuTile(
          icon: OlIcons.download,
          tone: (c.okSoft, c.ok),
          title: 'Export Excel',
          subtitle: 'Unduh data pemeriksaan per bulan',
          onTap: () => context.push(Routes.klinikExport),
        ),
        if (admin)
          KMenuTile(
            icon: OlIcons.users,
            tone: purple,
            title: 'User Management',
            subtitle: 'Tambah user, ubah password, hapus user',
            onTap: () => context.push(Routes.klinikUser),
          ),
        const OlSectionHeader(title: 'Akun'),
        KMenuTile(
          icon: OlIcons.lock,
          tone: (c.goldSoft, c.gold),
          title: 'Ubah password saya',
          subtitle: 'Ganti password masuk aplikasi',
          onTap: () => context.push(Routes.changePassword),
        ),
        KMenuTile(
          icon: OlIcons.help,
          title: 'Bantuan',
          subtitle: 'Panduan & kontak dukungan',
          onTap: () => context.push(Routes.help),
        ),
        KMenuTile(icon: OlIcons.logout, title: 'Keluar', danger: true, onTap: logout),
        Center(child: Text('One Lotus v$kAppVersion', style: t.caption)),
      ],
    );
  }
}
