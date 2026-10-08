import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _State { conflict, failed, sending, waiting }

class _Item {
  _Item(this.title, this.meta, this.state, {this.error});
  final String title;
  final String meta;
  _State state;
  final String? error;
}

/// UM-14 Status sinkron: daftar item outbox & statusnya. Item tidak bisa dihapus
/// agar catatan medis tidak hilang. (Slicing UI: isi contoh dari mockup.)
class SyncStatusPage extends StatefulWidget {
  const SyncStatusPage({super.key});

  @override
  State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage> {
  final _items = [
    _Item(
      'Foto rontgen · Andi Pratama',
      'Dibuat 10.41 · 3,2 MB',
      _State.failed,
      error: 'Gagal mengunggah. Sinyal terputus.',
    ),
    _Item(
      'Rekam sesi · Andi Pratama',
      'Dibuat 10.48 · mengirim…',
      _State.sending,
    ),
    _Item('Checklist alat · Budi Hartono', 'Dibuat 12.31', _State.waiting),
    _Item(
      'Kesimpulan sesi · Rina Setiawati',
      'Diubah 09.51 · juga diubah di tablet ruang 2',
      _State.conflict,
      error: 'Versi berbeda — pilih yang dipakai.',
    ),
  ];

  Future<void> _resolve(_Item i) async {
    final pick = await showConflictSheet(
      context,
      mine: const ConflictVersion(
        label: 'Versi HP ini · 09.51',
        text: 'Lanjut calf raise 3×12, kontrol Kamis.',
      ),
      theirs: const ConflictVersion(
        label: 'Versi tablet ruang 2 · 09.53',
        text: 'Lanjut calf raise 3×12 + kompres hangat, kontrol Kamis.',
      ),
    );
    if (pick == null || !mounted) return;
    setState(() => i.state = _State.sending);
    context.feedback.success(
      pick == 0 ? 'Versi HP ini dipakai.' : 'Versi tablet ruang 2 dipakai.',
    );
  }

  void _retry(_Item i) {
    setState(() => i.state = _State.sending);
    context.feedback.info('Mencoba mengirim lagi…');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final failed = _items
        .where((i) => i.state == _State.failed || i.state == _State.conflict)
        .length;
    final waiting = _items.length - failed;
    return OlDetailScaffold(
      title: 'Status sinkron',
      below: Align(
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
        OlButton(
          label: 'Coba lagi semua',
          onPressed: () {
            setState(() {
              for (final i in _items) {
                if (i.state == _State.failed) i.state = _State.sending;
              }
            });
            context.feedback.info('Mencoba mengirim semua…');
          },
        ),
        OlButton.text(
          label: 'Kirim log ke tim',
          expand: true,
          onPressed: () => context.feedback.success(
            'Log terkirim ke tim teknis. Ref: OL-7F3A',
          ),
        ),
      ],
      children: [
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (idx, i) in _items.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: idx < _items.length - 1
                        ? Border(bottom: BorderSide(color: c.line))
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OlIcon(
                        switch (i.state) {
                          _State.failed => OlIcons.cloudAlert,
                          _State.conflict => OlIcons.alert,
                          _State.sending => OlIcons.sync,
                          _State.waiting => OlIcons.clock,
                        },
                        color: switch (i.state) {
                          _State.failed => c.crit,
                          _State.conflict => c.warn,
                          _State.sending => c.warn,
                          _State.waiting => c.muted,
                        },
                        weight: OlIconWeight.duotone,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.title,
                              style: t.bodyStrong.copyWith(fontSize: 15),
                            ),
                            Text(
                              i.meta,
                              style: t.body.copyWith(color: c.muted),
                            ),
                            if ((i.state == _State.failed ||
                                    i.state == _State.conflict) &&
                                i.error != null)
                              Text(
                                i.error!,
                                style: t.body.copyWith(
                                  color: c.crit,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      switch (i.state) {
                        _State.failed => OlButton.secondary(
                          label: 'Coba lagi',
                          small: true,
                          expand: false,
                          onPressed: () => _retry(i),
                        ),
                        _State.conflict => OlButton.secondary(
                          label: 'Pilih versi',
                          small: true,
                          expand: false,
                          onPressed: () => _resolve(i),
                        ),
                        _State.sending => const OlTag(
                          'Mengirim',
                          tone: OlTagTone.warn,
                        ),
                        _State.waiting => const OlTag(
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
