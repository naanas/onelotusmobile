import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../ui/feedback/app_error.dart';
import '../api/api_error_mapper.dart';
import 'outbox.dart';

/// Hasil pengiriman satu item outbox.
sealed class SendOutcome {
  const SendOutcome();
}

class SendOk extends SendOutcome {
  const SendOk({this.serverVersion, this.response});
  final int? serverVersion;
  final Map<String, dynamic>? response;
}

class SendError extends SendOutcome {
  const SendError(this.error);
  final AppError error;
}

class SendConflict extends SendOutcome {
  const SendConflict({
    required this.serverPayload,
    required this.serverVersion,
  });
  final Map<String, dynamic> serverPayload;
  final int serverVersion;
}

/// Pengirim per jenis operasi (API atau mock).
abstract interface class OutboxSender {
  Future<SendOutcome> send(OutboxItem item);
}

/// Ringkasan status sinkron untuk SyncIndicator & UM-14.
@immutable
class SyncSnapshot {
  const SyncSnapshot({
    this.pending = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.sending = false,
    this.offline = false,
    this.lastSyncedAt,
    this.items = const [],
  });

  /// Belum terkirim (termasuk yang sedang dikirim).
  final int pending;
  final int failed;
  final int conflicts;
  final bool sending;
  final bool offline;
  final DateTime? lastSyncedAt;
  final List<OutboxItem> items;

  /// Total yang belum sampai server — dipakai dialog logout §12.5.
  int get unsynced => pending + failed + conflicts;
}

/// Mesin outbox (§8): simpan dulu di HP, kirim saat bisa, coba ulang dengan backoff.
class SyncEngine {
  SyncEngine({
    required this.store,
    required this.sender,
    DateTime Function()? clock,
    this.autoSchedule = true,
  }) : _now = clock ?? DateTime.now;

  final OutboxStore store;
  final OutboxSender sender;
  final DateTime Function() _now;

  /// Matikan di tes agar tidak ada Timer nyata.
  final bool autoSchedule;

  final snapshot = ValueNotifier<SyncSnapshot>(const SyncSnapshot());

  final _sent = StreamController<(OutboxItem, SendOk)>.broadcast();

  /// Item yang berhasil terkirim — repository memperbarui cache lokal dari respons server.
  Stream<(OutboxItem, SendOk)> get sent => _sent.stream;

  Future<void>? _run;
  bool _paused = false;
  bool _again = false;
  bool _offline = false;
  bool _disposed = false;
  DateTime? _lastSyncedAt;
  Timer? _timer;

  static const _baseDelay = Duration(seconds: 5);
  static const _maxDelay = Duration(minutes: 5);

  /// Jeda coba ulang: 5 dtk, 10, 20, 40 … maks 5 menit.
  static Duration backoff(int attempts) {
    final ms = _baseDelay.inMilliseconds * pow(2, max(0, attempts - 1));
    return Duration(milliseconds: min(ms.toInt(), _maxDelay.inMilliseconds));
  }

  Future<void> start() async {
    await store.resetSending();
    await _publish();
    unawaited(flush());
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_sent.close());
    snapshot.dispose();
  }

  /// Simpan operasi ke outbox lalu coba kirim. Perubahan berikutnya untuk entitas yang
  /// sama (selama belum terkirim) digabung — yang dikirim selalu versi terakhir.
  Future<OutboxItem> enqueue({
    required String kind,
    required String entityId,
    required Map<String, dynamic> payload,
    int baseVersion = 0,
    OutboxLane lane = OutboxLane.data,
  }) async {
    final now = _now();
    final existing = await store.pendingFor(kind, entityId);
    final item = existing != null
        ? existing.copyWith(payload: payload, nextAttemptAt: now)
        : OutboxItem(
            id: newId(),
            kind: kind,
            lane: lane,
            entityId: entityId,
            payload: payload,
            baseVersion: baseVersion,
            createdAt: now,
            nextAttemptAt: now,
          );
    await store.put(item);
    await _publish();
    unawaited(flush());
    return item;
  }

  /// Koneksi kembali / tombol "Coba lagi": kirim semua yang menunggu sekarang juga.
  Future<void> retryNow() async {
    _offline = false;
    for (final i in await store.all()) {
      if (i.status == OutboxStatus.pending) {
        await store.put(i.copyWith(nextAttemptAt: _now()));
      }
    }
    await flush();
  }

  void setOffline(bool offline) {
    if (_offline == offline) return;
    _offline = offline;
    if (!offline) {
      unawaited(retryNow());
    } else {
      unawaited(_publish());
    }
  }

  /// Item gagal (422/403) dicoba lagi setelah pengguna memperbaiki / meminta.
  Future<void> retry(String id) async {
    final i = await store.byId(id);
    if (i == null) return;
    await store.put(
      i.copyWith(
        status: OutboxStatus.pending,
        attempts: 0,
        nextAttemptAt: _now(),
        clearError: true,
      ),
    );
    await flush();
  }

  /// Buang perubahan lokal (setelah konfirmasi pengguna).
  Future<void> discard(String id) async {
    await store.delete(id);
    await _publish();
  }

  /// Konflik: pakai versi HP ini — kirim ulang dengan versi server terbaru sebagai dasar.
  Future<void> resolveKeepMine(String id) async {
    final i = await store.byId(id);
    if (i == null || i.status != OutboxStatus.conflict) return;
    await store.put(
      i.copyWith(
        status: OutboxStatus.pending,
        baseVersion: i.serverVersion,
        attempts: 0,
        nextAttemptAt: _now(),
        clearError: true,
        clearServer: true,
      ),
    );
    await flush();
  }

  /// Konflik: pakai versi server — perubahan lokal dibuang. Mengembalikan isi versi server.
  Future<Map<String, dynamic>?> resolveKeepServer(String id) async {
    final i = await store.byId(id);
    if (i == null || i.status != OutboxStatus.conflict) return null;
    await store.delete(id);
    await _publish();
    return i.serverPayload;
  }

  /// Jeda saat belum login (tanpa token): outbox tetap tersimpan, tidak dikirim.
  void setPaused(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    if (!paused) unawaited(flush());
  }

  /// Kirim semua yang sudah waktunya. Bila putaran sedang berjalan, permintaan ini
  /// ditandai untuk satu putaran lagi dan future-nya selesai bersama putaran tersebut.
  Future<void> flush() {
    if (_disposed || _paused) return Future.value();
    if (_run != null) {
      _again = true;
      return _run!;
    }
    return _run = _loop();
  }

  Future<void> _loop() async {
    try {
      do {
        _again = false;
        await _drain();
      } while (_again && !_disposed && !_paused);
    } finally {
      _run = null;
      if (!_disposed) {
        await _publish();
        await _scheduleNext();
      }
    }
  }

  Future<void> _drain() async {
    for (final item in await store.due(_now())) {
      if (_disposed) return;
      // Item mungkin berubah (digabung/dihapus) sejak daftar diambil.
      final current = await store.byId(item.id);
      if (current == null || current.status != OutboxStatus.pending) continue;

      await store.put(current.copyWith(status: OutboxStatus.sending));
      await _publish(sending: true);

      SendOutcome outcome;
      try {
        outcome = await sender.send(current);
      } on AppError catch (e) {
        outcome = SendError(e);
      } catch (_) {
        outcome = const SendError(AppError(ErrorCode.unknown));
      }

      switch (outcome) {
        case SendOk():
          _offline = false;
          _lastSyncedAt = _now();
          await store.delete(current.id);
          // Perubahan yang masuk selama pengiriman tersimpan sebagai item baru untuk entitas
          // yang sama: dasarkan pada versi server terbaru agar tidak dianggap konflik.
          final followUp = await store.pendingFor(
            current.kind,
            current.entityId,
          );
          if (followUp != null && outcome.serverVersion != null) {
            await store.put(
              followUp.copyWith(baseVersion: outcome.serverVersion),
            );
          }
          _sent.add((current, outcome));
        case SendConflict():
          await store.put(
            current.copyWith(
              status: OutboxStatus.conflict,
              serverPayload: outcome.serverPayload,
              serverVersion: outcome.serverVersion,
              lastError: ErrorCode.editConflict.code,
            ),
          );
        case SendError(:final error):
          if (isRetryable(error)) {
            final attempts = current.attempts + 1;
            await store.put(
              current.copyWith(
                status: OutboxStatus.pending,
                attempts: attempts,
                nextAttemptAt: _now().add(backoff(attempts)),
                lastError: error.code,
                lastErrorRef: error.refId,
              ),
            );
            if (error.type == ErrorCode.networkOffline ||
                error.type == ErrorCode.networkTimeout) {
              // Tidak ada sinyal: hentikan putaran ini, sisanya ikut menunggu.
              _offline = true;
              return;
            }
          } else {
            await store.put(
              current.copyWith(
                status: OutboxStatus.failed,
                attempts: current.attempts + 1,
                lastError: error.code,
                lastErrorRef: error.refId,
              ),
            );
          }
      }
      await _publish(sending: true);
    }
  }

  Future<void> _publish({bool sending = false}) async {
    if (_disposed) return;
    final items = await store.all();
    snapshot.value = SyncSnapshot(
      pending: items
          .where(
            (i) =>
                i.status == OutboxStatus.pending ||
                i.status == OutboxStatus.sending,
          )
          .length,
      failed: items.where((i) => i.status == OutboxStatus.failed).length,
      conflicts: items.where((i) => i.status == OutboxStatus.conflict).length,
      sending: sending,
      offline: _offline,
      lastSyncedAt: _lastSyncedAt,
      items: items,
    );
  }

  Future<void> _scheduleNext() async {
    _timer?.cancel();
    if (!autoSchedule || _disposed) return;
    final pending = (await store.all()).where(
      (i) => i.status == OutboxStatus.pending,
    );
    if (pending.isEmpty) return;
    final next = pending
        .map((i) => i.nextAttemptAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final wait = next.difference(_now());
    _timer = Timer(
      wait.isNegative ? Duration.zero : wait,
      () => unawaited(flush()),
    );
  }
}
