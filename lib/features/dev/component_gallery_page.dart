import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// /dev/komponen — galeri semua widget inti (§4) & feedback (§12.7). Hanya untuk pengecekan.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  bool _loading = false;
  String _seg = 'tangani';
  final _treatments = {'Adjustment'};
  SyncStatus _sync = const SyncSynced();
  String? _bbError = 'Berat badan harus angka, mis. 58';

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final fb = context.feedback;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            OlSpace.screen,
            22,
            OlSpace.screen,
            40,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '§4 Komponen inti · §12 Feedback',
                        style: t.caption.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text('Galeri komponen', style: t.title),
                    ],
                  ),
                ),
                SyncIndicator(status: _sync, onTap: _cycleSync),
              ],
            ),
            const SizedBox(height: OlSpace.md),
            const FeedbackBannerHost(),

            _section('Tombol'),
            OlButton(
              label: 'Simpan & kirim ringkasan',
              icon: OlIcons.send,
              onPressed: () {},
            ),
            const SizedBox(height: OlSpace.sm),
            OlButton(
              label: 'Konfirmasi pembayaran',
              loading: _loading,
              onPressed: () async {
                setState(() => _loading = true);
                await Future<void>.delayed(const Duration(seconds: 2));
                if (mounted) setState(() => _loading = false);
              },
            ),
            const SizedBox(height: OlSpace.sm),
            OlButton.secondary(label: 'Simpan saja', onPressed: () {}),
            const SizedBox(height: OlSpace.sm),
            const OlButton(label: 'Nonaktif', onPressed: null),
            const SizedBox(height: OlSpace.sm),
            OlButton.danger(label: 'Batalkan transaksi', onPressed: () {}),
            Wrap(
              spacing: OlSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OlButton.text(label: 'Lupa password?', onPressed: () {}),
                OlButton.secondary(
                  label: 'Riwayat',
                  small: true,
                  expand: false,
                  onPressed: () {},
                ),
                OlButton.secondary(
                  label: 'Tutup kas',
                  small: true,
                  expand: false,
                  onPressed: () {},
                ),
              ],
            ),

            _section('Kartu'),
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '09.00',
                        style: t.mono.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      OlTag.session(SessionStatus.done),
                    ],
                  ),
                  const SizedBox(height: OlSpace.sm),
                  Text('Rina Setiawati', style: t.heading),
                  Text(
                    'Cedera ringan · ankle kiri · sesi 4/5',
                    style: t.body.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: OlSpace.gap),
            OlCard(
              variant: OlCardVariant.now,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '10.30',
                        style: t.mono.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: OlSpace.sm),
                      const Spacer(),
                      Flexible(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Berjalan · 12:40',
                            style: t.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: OlSpace.sm),
                  Text(
                    'Andi Pratama',
                    style: t.heading.copyWith(color: Colors.white),
                  ),
                  Text(
                    'Adjustment Therapy · ruang 2',
                    style: t.body.copyWith(color: const Color(0xFFCDE9F9)),
                  ),
                  const SizedBox(height: OlSpace.md),
                  _WhiteButton(label: 'Buka rekam sesi', onPressed: () {}),
                ],
              ),
            ),
            const SizedBox(height: OlSpace.gap),
            OlCard(
              variant: OlCardVariant.gold,
              child: Row(
                children: [
                  OlIcon(OlIcons.package, color: c.gold),
                  const SizedBox(width: OlSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tawarkan paket 5× Adjustment?',
                          style: t.bodyStrong.copyWith(color: c.gold),
                        ),
                        Text(
                          'Hemat Rp125.000 dibanding bayar per sesi',
                          style: t.body.copyWith(color: c.gold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _section('Isian'),
            const OlTextField(
              label: 'Username',
              isRequired: true,
              hint: 'mis. dimas.terapis',
            ),
            const SizedBox(height: OlSpace.lg),
            const OlTextField(
              label: 'Password',
              isRequired: true,
              obscure: true,
              initialValue: 'rahasia123',
            ),
            const SizedBox(height: OlSpace.lg),
            OlTextField(
              label: 'Berat badan',
              initialValue: '5S',
              suffixText: 'kg',
              keyboardType: TextInputType.number,
              error: _bbError,
              onChanged: (v) => setState(
                () => _bbError = int.tryParse(v) == null
                    ? 'Berat badan harus angka, mis. 58'
                    : null,
              ),
            ),
            const SizedBox(height: OlSpace.lg),
            const OlTextField(
              label: 'Keluhan',
              helper: 'Diisi dari sesi lalu · ketuk untuk ubah',
              maxLines: 3,
            ),
            const SizedBox(height: OlSpace.lg),
            const OlTextField(
              label: 'Pakai paket',
              initialValue: 'Cedera Ringan 5× · kuota 0',
              enabled: false,
            ),

            _section('Chip & segmented'),
            OlSegmented<String>(
              segments: const {'tangani': 'Ditangani', 'penenang': 'Penenang'},
              value: _seg,
              onChanged: (v) => setState(() => _seg = v),
            ),
            const SizedBox(height: OlSpace.md),
            Wrap(
              spacing: OlSpace.sm,
              children: [
                for (final (name, icon) in [
                  ('Adjustment', OlIcons.hands),
                  ('Infrared', OlIcons.infrared),
                  ('Stretching', OlIcons.stretch),
                  ('Kinesio tape', OlIcons.tape),
                ])
                  OlChip(
                    label: name,
                    icon: icon,
                    selected: _treatments.contains(name),
                    onTap: () => setState(
                      () => _treatments.contains(name)
                          ? _treatments.remove(name)
                          : _treatments.add(name),
                    ),
                  ),
                OlChip(
                  label: 'Lumbal (L4–L5)',
                  selected: true,
                  small: true,
                  onRemove: () {},
                ),
                OlChip(label: '+ Lainnya', small: true, onTap: () {}),
              ],
            ),

            _section('StatusTag · siklus sesi'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in SessionStatus.values) OlTag.session(s),
                const OlTag(
                  'Home visit',
                  tone: OlTagTone.warn,
                  icon: OlIcons.homeVisit,
                ),
                const OlTag('Pasien baru', tone: OlTagTone.outline),
              ],
            ),
            _section('PaymentStatusBadge'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in PaymentStatus.values)
                  OlTag.payment(
                    s,
                    detail: s == PaymentStatus.partial ? 'Rp300.000' : null,
                  ),
              ],
            ),

            _section('SyncIndicator (ketuk untuk ganti)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                SyncIndicator(status: SyncSynced()),
                SyncIndicator(status: SyncSaving()),
                SyncIndicator(status: SyncOffline(2)),
                SyncIndicator(status: SyncFailed(3)),
              ],
            ),
            const SizedBox(height: OlSpace.sm),
            Container(
              padding: const EdgeInsets.all(OlSpace.md),
              decoration: BoxDecoration(
                color: c.brandDeep,
                borderRadius: BorderRadius.circular(OlRadius.card),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  SyncIndicator(status: SyncSynced(), onHero: true),
                  SyncIndicator(status: SyncOffline(2), onHero: true),
                  SyncIndicator(status: SyncFailed(3), onHero: true),
                ],
              ),
            ),

            _section('Daftar & avatar'),
            OlCard(
              padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
              child: Column(
                children: [
                  OlListItem(
                    leading: const OlAvatar(name: 'Rina Setiawati'),
                    title: 'Rina Setiawati',
                    subtitle: '#0387 · terakhir 2 Okt',
                    trailing: const OlTag('Paket 2/5', tone: OlTagTone.brand),
                    showChevron: true,
                    onTap: () {},
                  ),
                  OlListItem(
                    leading: const OlAvatar(name: 'Budi Hartono'),
                    title: 'Budi Hartono',
                    subtitle: '#0201 · belum kembali 34 hari',
                    trailing: const OlTag('>30 hari', tone: OlTagTone.warn),
                    showChevron: true,
                    divider: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: OlSpace.sm),
            const Row(
              children: [
                OlAvatar(name: 'Andi Pratama', large: true),
                SizedBox(width: 12),
                OlAvatar(name: 'dimas'),
              ],
            ),

            _section('Banner'),
            const OlBanner(
              message: 'Kamu sedang offline. Data tersimpan di HP.',
              tone: OlBannerTone.warn,
              icon: OlIcons.offline,
            ),
            const SizedBox(height: OlSpace.sm),
            const OlBanner(
              message: 'Riwayat LBP kronis — hindari tekanan kuat di L4–L5.',
              tone: OlBannerTone.crit,
            ),
            const SizedBox(height: OlSpace.sm),
            const OlBanner(message: 'Bukti transfer menunggu verifikasi.'),
            const SizedBox(height: OlSpace.sm),
            OlBanner(
              message: '3 catatan belum terkirim.',
              tone: OlBannerTone.ok,
              actionLabel: 'Detail',
              onAction: () {},
            ),

            _section('Skeleton & state kosong'),
            const SkeletonList(count: 2),
            const SizedBox(height: OlSpace.gap),
            OlCard(
              child: EmptyState(
                illustration: OlIllustration.emptySchedule,
                message: 'Tidak ada sesi hari ini.',
                actionLabel: 'Lihat jadwal minggu ini',
                onAction: () {},
              ),
            ),

            _section('Feedback · toast'),
            _demo(
              'Toast sukses',
              () => fb.success('Sesi tersimpan. Ringkasan dikirim ke Andi.'),
            ),
            _demo(
              'Toast sukses + aksi',
              () => fb.success(
                'Pasien #0413 dibuat.',
                action: FeedbackAction('Jadwalkan', () {}),
              ),
            ),
            _demo(
              'Toast info (rate_limited)',
              () => fb.error(const AppError(ErrorCode.rateLimited)),
            ),
            _demo(
              'Toast error + ref + coba lagi',
              () => fb.error(
                const AppError(ErrorCode.serverError, refId: 'OL-7F3A'),
                retry: () {},
              ),
            ),
            _demo(
              'Toast error (forbidden)',
              () => fb.error(const AppError(ErrorCode.forbidden)),
            ),

            _section('Feedback · banner'),
            _demo(
              'Banner offline',
              () => fb.error(const AppError(ErrorCode.networkOffline)),
            ),
            _demo(
              'Banner pembayaran menunggu',
              () => fb.error(const AppError(ErrorCode.paymentPendingUnknown)),
            ),
            _demo('Hapus semua banner', () {
              for (final b in [...fb.banners.value]) {
                fb.clearBanner(b.id);
              }
            }),

            _section('Feedback · bottom sheet'),
            _demo(
              'Sinkron gagal',
              () => fb.error(
                const AppError(ErrorCode.syncFailed, args: {'n': 3}),
                retry: () => fb.info('Mencoba sinkron lagi…'),
              ),
            ),
            _demo('Pasien ganda', () async {
              final open = await fb.sheet<bool>(
                title: 'Pasien dengan nama & tanggal lahir ini sudah ada.',
                message: 'Rina Setiawati · #0387 · lahir 12 Mar 1990',
                actions: const [
                  SheetAction('Buka data lama', true),
                  SheetAction(
                    'Tetap buat baru',
                    false,
                    variant: OlButtonVariant.secondary,
                  ),
                ],
              );
              if (open != null) {
                fb.info(open ? 'Membuka data lama' : 'Membuat pasien baru');
              }
            }),

            _section('Feedback · dialog §12.5'),
            _demo(
              'Arsipkan pasien',
              () => fb.confirm(
                const ConfirmSpec(
                  title: 'Arsipkan data Rina Setiawati?',
                  message:
                      'Pasien tidak muncul di daftar aktif. Riwayat terapi tetap tersimpan dan bisa dipulihkan oleh admin atau owner.',
                  confirmLabel: 'Arsipkan',
                ),
              ),
            ),
            _demo('Batalkan transaksi (wajib alasan)', () async {
              final r = await fb.choose(
                const ConfirmSpec(
                  title: 'Batalkan transaksi Rp450.000?',
                  message: 'Tagihan jadi Dibatalkan. Sesi tetap tercatat.',
                  confirmLabel: 'Batalkan transaksi',
                  reasonLabel: 'Alasan',
                ),
              );
              if (r.confirmed) fb.success('Transaksi dibatalkan: ${r.reason}');
            }),
            _demo('Keluar tanpa simpan (3 pilihan)', () async {
              final r = await fb.choose(
                const ConfirmSpec(
                  title: 'Simpan dulu catatan ini?',
                  message: 'Ada perubahan di rekam sesi yang belum disimpan.',
                  confirmLabel: 'Simpan',
                  danger: false,
                  alternativeLabel: 'Buang perubahan',
                ),
              );
              fb.info('Pilihan: ${r.choice.name}');
            }),
            _demo(
              'Logout belum sinkron',
              () => fb.choose(
                const ConfirmSpec(
                  title: 'Ada 3 catatan belum terkirim',
                  message:
                      'Kalau keluar sekarang, catatan yang belum terkirim bisa hilang.',
                  confirmLabel: 'Tunggu sinkron',
                  danger: false,
                  alternativeLabel: 'Tetap keluar',
                ),
              ),
            ),

            _section('Ikon (${OlIcons.all.length})'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in OlIcons.all)
                  Tooltip(
                    message: i.name,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: OlIcon(i, color: c.fg),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: OlSpace.sm),
            Row(
              children: [
                OlIcon(OlIcons.calendar, color: c.brand),
                const SizedBox(width: 8),
                OlIcon(
                  OlIcons.calendar,
                  color: c.brand,
                  weight: OlIconWeight.fill,
                ),
                const SizedBox(width: 8),
                OlIcon(
                  OlIcons.calendar,
                  color: c.brand,
                  weight: OlIconWeight.duotone,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('regular · fill · duotone', style: t.caption),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _cycleSync() => setState(() {
    _sync = switch (_sync) {
      SyncSynced() => const SyncSaving(),
      SyncSaving() => const SyncOffline(2),
      SyncOffline() => const SyncFailed(3),
      SyncFailed() => const SyncSynced(),
    };
  });

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Text(label.toUpperCase(), style: context.olText.overline),
  );

  Widget _demo(String label, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: OlSpace.sm),
    child: OlButton.secondary(label: label, small: true, onPressed: onTap),
  );
}

/// Tombol putih di dalam kartu "now" (`.card.now .btn`). Akan dipindah ke SessionCard di Fase 1.
class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: OlSize.button,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: context.ol.brandDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OlRadius.button),
        ),
        textStyle: context.olText.button,
      ),
      child: Text(label),
    ),
  );
}
