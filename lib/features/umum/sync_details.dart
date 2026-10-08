import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../ui/ui.dart';

/// Ketuk SyncIndicator: saat ada yang gagal → sheet ST-07; selain itu → UM-14.
Future<void> openSyncDetails(BuildContext context, SyncStatus status) async {
  if (status is! SyncFailed) {
    context.push(Routes.syncStatus);
    return;
  }
  // Slicing UI: isi contoh dari mockup ST-07 (nanti dari outbox).
  final fb = context.feedback;
  final retryAll = await showSyncIssuesSheet(
    context,
    items: const [
      SyncIssue(
        title: 'Foto rontgen · Andi Pratama',
        detail: 'Gagal mengunggah · 3,2 MB',
        failed: true,
      ),
      SyncIssue(title: 'Rekam sesi · Andi Pratama', detail: 'Menunggu koneksi'),
      SyncIssue(title: 'Checklist · Budi Hartono', detail: 'Menunggu koneksi'),
    ],
    onRetryOne: (it) => fb.info('Mengunggah ulang ${it.title}…'),
  );
  if (retryAll == true) fb.info('Mencoba mengirim semua…');
}
