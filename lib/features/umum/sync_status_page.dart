import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/sync/outbox.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'sync_items.dart';

/// UM-14 Status sinkron: isi outbox di HP ini (rekam sesi, status sesi, permintaan pindah jadwal)
/// dan statusnya. Item tidak bisa dihapus dari sini agar catatan medis tidak hilang; konflik
/// dipilih versinya (ST-09), yang gagal bisa dicoba lagi.
class SyncStatusPage extends ConsumerStatefulWidget {
  const SyncStatusPage({super.key});

  @override
  ConsumerState<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends ConsumerState<SyncStatusPage> {
  List<OutboxItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ref.read(syncEngineProvider).store.all();
    if (mounted) setState(() => _items = all);
  }

  Future<void> _resolve(OutboxItem i) async {
    final engine = ref.read(syncEngineProvider);
    String text(Map<String, dynamic>? p) => [
      p?['complaint'],
      p?['conclusion'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final pick = await showConflictSheet(
      context,
      mine: ConflictVersion(label: 'Versi HP ini', text: text(i.payload)),
      theirs: ConflictVersion(
        label: 'Versi server',
        text: text(i.serverPayload),
      ),
    );
    if (pick == null || !mounted) return;
    if (pick == 0) {
      await engine.resolveKeepMine(i.id);
    } else {
      await engine.resolveKeepServer(i.id);
    }
    if (!mounted) return;
    context.feedback.success(
      pick == 0 ? 'Versi HP ini dipakai.' : 'Versi server dipakai.',
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // Muat ulang tiap kali status sinkron berubah (terkirim, gagal, konflik).
    ref.listen(syncSnapshotProvider, (_, _) => _load());
    final c = context.ol;
    final t = context.olText;
    final items = _items;
    final failed =
        items
            ?.where(
              (i) =>
                  i.status == OutboxStatus.failed ||
                  i.status == OutboxStatus.conflict,
            )
            .length ??
        0;
    final waiting = (items?.length ?? 0) - failed;
    return OlDetailScaffold(
      title: 'Status sinkron',
      below: items == null || items.isEmpty
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: SyncIndicator(
                status: failed > 0 ? SyncFailed(failed) : SyncOffline(waiting),
                label: [
                  if (failed > 0) '$failed gagal',
                  if (waiting > 0) '$waiting menunggu',
                ].join(' · '),
              ),
            ),
      foot: [
        if (items != null && items.isNotEmpty)
          OlButton(
            label: 'Coba kirim sekarang',
            onPressed: () async {
              final engine = ref.read(syncEngineProvider);
              for (final i in items) {
                if (i.status == OutboxStatus.failed) await engine.retry(i.id);
              }
              await engine.retryNow();
              if (context.mounted) {
                context.feedback.info('Mencoba mengirim semua…');
              }
              _load();
            },
          ),
      ],
      children: [
        if (items == null)
          const OlLoadingCard()
        else if (items.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptyInbox,
              title: 'Semua sudah tersinkron',
              message: 'Tidak ada catatan yang menunggu dikirim dari HP ini.',
            ),
          )
        else
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (idx, i) in items.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: idx < items.length - 1
                          ? Border(bottom: BorderSide(color: c.line))
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OlIcon(
                          switch (i.status) {
                            OutboxStatus.failed => OlIcons.cloudAlert,
                            OutboxStatus.conflict => OlIcons.alert,
                            OutboxStatus.sending => OlIcons.sync,
                            OutboxStatus.pending => OlIcons.clock,
                          },
                          color: switch (i.status) {
                            OutboxStatus.failed => c.crit,
                            OutboxStatus.conflict ||
                            OutboxStatus.sending => c.warn,
                            OutboxStatus.pending => c.muted,
                          },
                          weight: OlIconWeight.duotone,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                outboxTitle(i),
                                style: t.bodyStrong.copyWith(fontSize: 15),
                              ),
                              Text(
                                outboxMeta(i),
                                style: t.body.copyWith(color: c.muted),
                              ),
                              if (i.lastError != null &&
                                  (i.status == OutboxStatus.failed ||
                                      i.status == OutboxStatus.conflict))
                                Text(
                                  [
                                    i.lastError!,
                                    if (i.lastErrorRef != null)
                                      'Kode ${i.lastErrorRef}',
                                  ].join(' · '),
                                  style: t.body.copyWith(
                                    color: c.crit,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        switch (i.status) {
                          OutboxStatus.failed => OlButton.secondary(
                            label: 'Coba lagi',
                            small: true,
                            expand: false,
                            onPressed: () async {
                              await ref.read(syncEngineProvider).retry(i.id);
                              _load();
                            },
                          ),
                          OutboxStatus.conflict => OlButton.secondary(
                            label: 'Pilih versi',
                            small: true,
                            expand: false,
                            onPressed: () => _resolve(i),
                          ),
                          OutboxStatus.sending => const OlTag(
                            'Mengirim',
                            tone: OlTagTone.warn,
                          ),
                          OutboxStatus.pending => const OlTag(
                            'Menunggu',
                            tone: OlTagTone.muted,
                          ),
                        },
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Text(
          'Item di sini tidak bisa dihapus agar catatan medis tidak hilang. Semua terkirim otomatis saat koneksi kembali.',
          style: t.body.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
