import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_controller.dart';
import '../../data/sync/sync_providers.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'role_shell.dart';

/// Tab yang layarnya belum dibangun. Diganti satu per satu lewat `/layar <ID>`.
class PlaceholderTabPage extends ConsumerWidget {
  const PlaceholderTabPage({
    super.key,
    required this.title,
    required this.screenId,
    required this.stage,
    this.illustration = OlIllustration.emptySchedule,
    this.hero = false,
  });

  final String title;
  final String screenId;

  /// Tahap playbook / fase saat layar ini dibangun.
  final String stage;
  final OlIllustration illustration;

  /// Beranda peran memakai header hero (TR-01, KS-01, OW-01).
  final bool hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authProvider.select((s) => s.user?.firstName ?? ''));
    final sync = ref.watch(syncStatusProvider);
    return Column(
      children: [
        OlAppHeader(
          hero: hero,
          title: hero && screenId == 'TR-01' ? _greeting(name) : title,
          context_: headerContext(ref, DateTime.now()),
          below: SyncIndicator(status: sync, onHero: hero),
        ),
        Expanded(
          child: Transform.translate(
            offset: Offset(0, hero ? -56 : 0),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                OlSpace.screen,
                0,
                OlSpace.screen,
                24,
              ),
              children: [
                const FeedbackBannerHost(),
                OlCard(
                  child: EmptyState(
                    illustration: illustration,
                    title: '$screenId · $title',
                    message: 'Layar ini dibangun di $stage.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _greeting(String name) {
    final h = DateTime.now().hour;
    final part = h < 11
        ? 'Pagi'
        : (h < 15 ? 'Siang' : (h < 18 ? 'Sore' : 'Malam'));
    return '$part, $name';
  }
}

/// Layar penuh (di atas tab bar) yang belum dibangun, mis. tujuan FAB.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.screenId,
    required this.stage,
  });

  final String title;
  final String screenId;
  final String stage;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        OlAppHeader(title: title, leading: const OlBackButton()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.screen),
            children: [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptySearch,
                  title: '$screenId · $title',
                  message: 'Layar ini dibangun di $stage.',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
