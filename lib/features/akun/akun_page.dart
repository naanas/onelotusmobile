import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/staff_user.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_providers.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-11 Akun. Menu yang layarnya belum dibangun disembunyikan (§7: sembunyikan, bukan nonaktifkan).
// TODO(UM-12/13/14/15, TR-11, TR-12, B.1): tambahkan menu saat layarnya dibangun.
class AkunPage extends ConsumerWidget {
  const AkunPage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final pending = ref.read(pendingSyncCountProvider);
    final fb = context.feedback;
    if (pending > 0) {
      // §12.5: logout dengan data belum tersinkron.
      final r = await fb.choose(
        ConfirmSpec(
          title: 'Ada $pending catatan belum terkirim',
          message:
              'Kalau keluar sekarang, catatan yang belum terkirim bisa hilang.',
          confirmLabel: 'Tunggu sinkron',
          danger: false,
          alternativeLabel: 'Tetap keluar',
        ),
      );
      if (r.choice != ConfirmChoice.alternative) return;
    } else {
      final ok = await fb.confirm(
        const ConfirmSpec(
          title: 'Keluar dari One Lotus?',
          message: 'Kamu perlu masuk lagi dengan username & password.',
          confirmLabel: 'Keluar',
        ),
      );
      if (!ok) return;
    }
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ol;
    final t = context.olText;
    final s = ref.watch(authProvider);
    final user = s.user;
    final role = s.activeRole;
    final branch = s.activeBranch;
    // Sesaat setelah logout, sebelum redirect ke login.
    if (user == null || role == null || branch == null) {
      return const SizedBox.shrink();
    }
    final sync = ref.watch(syncStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider);
    final roleBranch =
        '${role == Role.kasir ? 'Kasir' : role.label} · ${branch.name}';

    return OlPageBody(
      header: const OlAppHeader(title: 'Akun'),
      children: [
        OlCard(
          child: Row(
            children: [
              OlAvatar(name: user.name, large: true),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: t.heading.copyWith(fontSize: 17)),
                    Text(roleBranch, style: t.caption.copyWith(fontSize: 13)),
                    const SizedBox(height: 6),
                    SyncIndicator(status: sync),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Group(
          children: [
            if (user.needsContextChoice)
              OlListItem(
                title: 'Ganti peran / cabang',
                subtitle: roleBranch,
                showChevron: true,
                onTap: () => context.push(Routes.chooseContext),
              ),
            if (role == Role.terapis) ...[
              OlListItem(
                title: 'Kas dibawa',
                subtitle: 'Rp445.000 belum diserahkan',
                trailing: const OlTag('1', tone: OlTagTone.warn),
                onTap: () => context.push(Routes.terapisKas),
              ),
              OlListItem(
                title: 'Komisi saya',
                showChevron: true,
                onTap: () => context.push(Routes.terapisKomisi),
              ),
            ],
            OlListItem(
              title: 'Status sinkron',
              trailing: Text(
                '$pending menunggu',
                style: t.body.copyWith(color: c.muted),
              ),
            ),
            if (kDebugMode && AppConfig.useMock)
              OlListItem(
                title: 'Simulasi offline',
                subtitle: 'Mode mock · khusus build debug',
                trailing: OlToggle(
                  semanticLabel: 'Simulasi offline',
                  value: ref.watch(mockOfflineProvider),
                  onChanged: (v) =>
                      ref.read(mockOfflineProvider.notifier).set(v),
                ),
              ),
            if (kDebugMode)
              OlListItem(
                title: 'Galeri komponen',
                subtitle: 'Khusus build debug',
                showChevron: true,
                onTap: () => context.push(Routes.devComponents),
              ),
          ],
        ),
        OlButton(
          label: 'Keluar',
          variant: OlButtonVariant.dangerSecondary,
          onPressed: () => _logout(context, ref),
        ),
        Center(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Versi '),
                TextSpan(
                  text: kAppVersion,
                  style: t.mono.copyWith(color: c.muted),
                ),
              ],
            ),
            style: t.caption.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<OlListItem> children;

  @override
  Widget build(BuildContext context) => OlCard(
    padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
    child: Column(
      children: [
        for (final (i, w) in children.indexed)
          i == children.length - 1 ? w.withoutDivider() : w,
      ],
    ),
  );
}
