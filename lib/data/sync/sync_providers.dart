import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/sync_indicator.dart';
import '../providers.dart';

/// Jumlah catatan yang belum sampai server (pending + gagal + konflik).
final pendingSyncCountProvider = Provider<int>(
  (ref) => ref.watch(syncSnapshotProvider).unsynced,
);

/// Status global untuk SyncIndicator (§4).
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final s = ref.watch(syncSnapshotProvider);
  if (s.failed + s.conflicts > 0) return SyncFailed(s.failed + s.conflicts);
  if (s.offline && s.pending > 0) return SyncOffline(s.pending);
  if (s.offline) return const SyncOffline(0);
  if (s.sending || s.pending > 0) return const SyncSaving();
  return const SyncSynced();
});
