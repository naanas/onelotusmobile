import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../data/sync/outbox.dart';
import '../../router/routes.dart';
import '../../ui/ui.dart';
import 'sync_items.dart';

/// Ketuk SyncIndicator: saat ada yang gagal → sheet ST-07 berisi item outbox yang gagal/konflik;
/// selain itu → UM-14.
Future<void> openSyncDetails(BuildContext context, SyncStatus status) async {
  if (status is! SyncFailed) {
    context.push(Routes.syncStatus);
    return;
  }
  final engine = ProviderScope.containerOf(context).read(syncEngineProvider);
  final fb = context.feedback;
  final items = [
    for (final i in await engine.store.all())
      if (i.status == OutboxStatus.failed || i.status == OutboxStatus.conflict)
        i,
  ];
  if (!context.mounted) return;
  if (items.isEmpty) {
    context.push(Routes.syncStatus);
    return;
  }
  final byIssue = <SyncIssue, OutboxItem>{
    for (final i in items)
      SyncIssue(
        title: outboxTitle(i),
        detail:
            i.lastError ??
            (i.status == OutboxStatus.conflict
                ? 'Versi berbeda — pilih di Status sinkron'
                : 'Gagal dikirim'),
        failed: true,
      ): i,
  };
  final retryAll = await showSyncIssuesSheet(
    context,
    items: byIssue.keys.toList(),
    onRetryOne: (it) {
      final i = byIssue[it];
      if (i != null) engine.retry(i.id);
      fb.info('Mencoba mengirim ulang…');
    },
  );
  if (retryAll == true) {
    for (final i in items) {
      if (i.status == OutboxStatus.failed) await engine.retry(i.id);
    }
    fb.info('Mencoba mengirim semua…');
  }
}
