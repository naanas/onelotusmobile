import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/sync_indicator.dart';

/// Jumlah catatan di outbox yang belum terkirim.
/// TODO(tahap-4): ganti dengan stream dari outbox lokal (§8).
final pendingSyncCountProvider = Provider<int>((ref) => 0);

/// Status global untuk SyncIndicator.
/// TODO(tahap-4): turunkan dari outbox + status koneksi.
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final pending = ref.watch(pendingSyncCountProvider);
  return pending > 0 ? SyncOffline(pending) : const SyncSynced();
});
