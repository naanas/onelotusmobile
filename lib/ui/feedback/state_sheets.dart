import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../ol_avatar.dart';
import '../ol_button.dart';
import '../ol_icon.dart';
import '../ol_tag.dart';

/// Kerangka bottom sheet state (§12.3): judul (opsional ikon), penjelasan, isi, tombol.
Future<T?> _stateSheet<T>(
  BuildContext context, {
  required String title,
  String? message,
  OlIconData? icon,
  Color? iconColor,
  required Widget Function(BuildContext context, void Function(T) close)
  builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) {
    final t = ctx.olText;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        OlSpace.xl,
        0,
        OlSpace.xl,
        OlSpace.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                if (icon != null) ...[
                  OlIcon(icon, color: iconColor ?? ctx.ol.fg),
                  const SizedBox(width: OlSpace.md),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: t.heading.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: OlSpace.sm),
            Text(message, style: t.body.copyWith(color: ctx.ol.muted)),
          ],
          const SizedBox(height: OlSpace.lg),
          builder(ctx, (r) => Navigator.of(ctx).pop(r)),
        ],
      ),
    );
  },
);

// ── ST-07 Sinkron gagal ─────────────────────────────────────────────────────

/// Satu catatan di antrean kirim untuk sheet ST-07.
class SyncIssue {
  const SyncIssue({
    required this.title,
    required this.detail,
    this.failed = false,
  });

  final String title;
  final String detail;

  /// Gagal (merah + tombol Ulangi) vs masih antre menunggu koneksi.
  final bool failed;
}

/// ST-07: daftar catatan belum terkirim. Hasil `true` = "Coba lagi semua".
/// [onRetryOne] dipanggil saat "Ulangi" per item ditekan.
Future<bool?> showSyncIssuesSheet(
  BuildContext context, {
  required List<SyncIssue> items,
  ValueChanged<SyncIssue>? onRetryOne,
}) => _stateSheet<bool>(
  context,
  title: '${items.length} catatan belum terkirim',
  message:
      'Semua tetap aman di HP. Kami akan mencoba lagi otomatis saat sinyal stabil.',
  icon: OlIcons.cloudAlert,
  iconColor: context.ol.crit,
  builder: (ctx, close) {
    final c = ctx.ol;
    final t = ctx.olText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(OlRadius.card),
            boxShadow: OlShadow.sh1,
          ),
          child: Column(
            children: [
              for (final (i, it) in items.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: i < items.length - 1
                        ? Border(bottom: BorderSide(color: c.line))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.title,
                              style: t.body.copyWith(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              it.detail,
                              style: t.body.copyWith(
                                fontSize: 14,
                                color: it.failed ? c.crit : c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: OlSpace.sm),
                      if (it.failed)
                        OlButton.secondary(
                          label: 'Ulangi',
                          small: true,
                          expand: false,
                          onPressed: () => onRetryOne?.call(it),
                        )
                      else
                        const OlTag('Antre', tone: OlTagTone.muted),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: OlSpace.lg),
        OlButton(label: 'Coba lagi semua', onPressed: () => close(true)),
      ],
    );
  },
);

// ── Kartu pilihan (ST-08, ST-09) ────────────────────────────────────────────

/// Kartu pilihan tunggal di sheet: terpilih = garis brand + halo.
class OlChoiceCard extends StatelessWidget {
  const OlChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.avatarName,
    this.radio = false,
    this.muted = false,
    this.monoTitle = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// Bila diisi, tampil avatar inisial di kiri.
  final String? avatarName;

  /// Tampilkan radio di kanan (ST-09).
  final bool radio;

  /// Latar abu (mis. "Isian baru" di ST-08).
  final bool muted;
  final bool monoTitle;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final radius = BorderRadius.circular(OlRadius.card);
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: OlMotion.of(context, OlMotion.fast),
        decoration: BoxDecoration(
          color: muted && !selected ? c.surfaceAlt : c.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? c.brand : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: c.brand.withValues(alpha: 0.14),
                    spreadRadius: 4,
                  ),
                ]
              : OlShadow.sh1,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(OlSpace.lg),
              child: Row(
                children: [
                  if (avatarName != null) ...[
                    Opacity(
                      opacity: muted ? 0.6 : 1,
                      child: OlAvatar(name: avatarName!),
                    ),
                    const SizedBox(width: OlSpace.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: t.bodyStrong.copyWith(fontSize: 15.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: t.body.copyWith(
                            fontSize: 14.5,
                            color: radio ? c.fg : c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (radio) ...[
                    const SizedBox(width: OlSpace.md),
                    _Radio(selected: selected),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? c.brand : c.faint, width: 2),
      ),
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
            )
          : null,
    );
  }
}

// ── ST-08 Pasien ganda ──────────────────────────────────────────────────────

enum DuplicateChoice { openExisting, createNew }

/// Ringkasan satu data pasien untuk dibandingkan di ST-08.
class PatientBrief {
  const PatientBrief({required this.name, required this.detail, this.number});

  final String name;
  final String? number;
  final String detail;
}

/// ST-08: nama & tanggal lahir sama. Default memilih data lama.
Future<DuplicateChoice?> showDuplicatePatientSheet(
  BuildContext context, {
  required PatientBrief existing,
  required PatientBrief incoming,
}) => _stateSheet<DuplicateChoice>(
  context,
  title: 'Pasien dengan nama & tanggal lahir ini sudah ada.',
  message: 'Gunakan data lama agar riwayat terapi tidak terpecah.',
  builder: (ctx, close) {
    var pick = DuplicateChoice.openExisting;
    return StatefulBuilder(
      builder: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OlChoiceCard(
            avatarName: existing.name,
            title: '${existing.name} · ${existing.number}',
            subtitle: existing.detail,
            selected: pick == DuplicateChoice.openExisting,
            onTap: () => set(() => pick = DuplicateChoice.openExisting),
          ),
          const SizedBox(height: OlSpace.md),
          OlChoiceCard(
            avatarName: incoming.name,
            title: 'Isian baru',
            subtitle: incoming.detail,
            muted: true,
            selected: pick == DuplicateChoice.createNew,
            onTap: () => set(() => pick = DuplicateChoice.createNew),
          ),
          const SizedBox(height: OlSpace.lg),
          OlButton(
            label: 'Buka data lama & perbarui',
            onPressed: () => close(DuplicateChoice.openExisting),
          ),
          const SizedBox(height: OlSpace.sm),
          OlButton.secondary(
            label: 'Tetap buat pasien baru',
            onPressed: () => close(DuplicateChoice.createNew),
          ),
        ],
      ),
    );
  },
);

// ── ST-09 Konflik edit ──────────────────────────────────────────────────────

/// Satu versi catatan yang bentrok.
class ConflictVersion {
  const ConflictVersion({required this.label, required this.text});
  final String label;
  final String text;
}

/// ST-09: catatan diubah di dua perangkat. Hasil = indeks versi yang dipakai
/// (0 = versi HP ini). Versi lain tetap tersimpan di riwayat perubahan.
Future<int?> showConflictSheet(
  BuildContext context, {
  required ConflictVersion mine,
  required ConflictVersion theirs,
  String what = 'kesimpulan',
}) => _stateSheet<int>(
  context,
  title: 'Catatan ini juga diubah di perangkat lain.',
  message:
      'Pilih versi $what yang dipakai. Versi lainnya tetap tersimpan di riwayat perubahan.',
  builder: (ctx, close) {
    var pick = 0;
    return StatefulBuilder(
      builder: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, v) in [mine, theirs].indexed) ...[
            if (i > 0) const SizedBox(height: OlSpace.md),
            OlChoiceCard(
              title: v.label,
              subtitle: v.text,
              radio: true,
              selected: pick == i,
              onTap: () => set(() => pick = i),
            ),
          ],
          const SizedBox(height: OlSpace.lg),
          OlButton(label: 'Pakai versi terpilih', onPressed: () => close(pick)),
        ],
      ),
    );
  },
);
