import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_controller.dart';
import '../../data/sync/sync_providers.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// ST-15 Layar error penuh — `auth_expired` (401).
class SessionExpiredPage extends ConsumerWidget {
  const SessionExpiredPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.olText;
    final pending = ref.watch(pendingSyncCountProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(OlSpace.xxl),
                  child: Column(
                    children: [
                      const OlIllustrationImage(
                        OlIllustration.sessionLocked,
                        width: 220,
                      ),
                      const SizedBox(height: 28),
                      Semantics(
                        header: true,
                        child: Text(
                          'Sesi login berakhir',
                          textAlign: TextAlign.center,
                          style: t.title,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Masuk lagi untuk melanjutkan. Catatan yang tersimpan di HP tetap aman dan akan dikirim setelah kamu masuk.',
                        textAlign: TextAlign.center,
                        style: t.body.copyWith(
                          fontSize: 15,
                          color: context.ol.muted,
                        ),
                      ),
                      if (pending > 0) ...[
                        const SizedBox(height: 16),
                        SyncIndicator(
                          status: SyncOffline(pending),
                          label: '$pending catatan menunggu sinkron',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            OlFootBar(
              children: [
                OlButton(
                  label: 'Masuk lagi',
                  onPressed: () => ref
                      .read(authProvider.notifier)
                      .acknowledgeSessionExpired(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
