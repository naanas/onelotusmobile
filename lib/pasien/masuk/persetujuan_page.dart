import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_session.dart';

/// PS-04 Persetujuan data (§10): ringkasan kebijakan + persetujuan wajib/opsional.
/// [review] = dibuka ulang dari Profil (bisa ubah promo, tanpa lanjut ke beranda).
class PersetujuanPage extends ConsumerStatefulWidget {
  const PersetujuanPage({super.key, this.review = false});

  final bool review;

  @override
  ConsumerState<PersetujuanPage> createState() => _PersetujuanPageState();
}

class _PersetujuanPageState extends ConsumerState<PersetujuanPage> {
  late bool _health = widget.review;
  late bool _reminder = widget.review;
  late bool _promo = widget.review
      ? ref.read(pasienSessionProvider).promoConsent
      : false;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget item(
      String title,
      String sub,
      bool v,
      ValueChanged<bool> onChanged, {
      bool required = false,
      bool locked = false,
    }) => OlCard(
      padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg, vertical: 6),
      child: OlCheckbox(
        label: required ? '$title *' : title,
        subtitle: sub,
        value: v,
        onChanged: locked ? (_) {} : onChanged,
      ),
    );

    return OlDetailScaffold(
      title: 'Data Anda, kendali Anda',
      showBack: widget.review,
      background: widget.review ? null : c.surface,
      foot: [
        OlButton(
          label: widget.review ? 'Simpan' : 'Setuju & lanjutkan',
          onPressed: _health && _reminder
              ? () {
                  if (widget.review) {
                    ref
                        .read(pasienSessionProvider.notifier)
                        .consented(promo: _promo);
                    context.feedback.success('Persetujuan disimpan.');
                    Navigator.of(context).maybePop();
                  } else {
                    ref
                        .read(pasienSessionProvider.notifier)
                        .consented(promo: _promo);
                  }
                }
              : null,
        ),
      ],
      children: [
        Text(
          'Kami menyimpan catatan terapi untuk membantu pemulihan Anda. Pilih apa yang Anda izinkan.',
          style: t.body.copyWith(fontSize: 15, color: c.muted),
        ),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: c.surfaceAlt.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ringkasan kebijakan', style: t.bodyStrong),
              const SizedBox(height: 6),
              for (final s in const [
                'Catatan terapi hanya dilihat terapis & staf berwenang',
                'Data tidak dijual atau dibagikan ke pihak lain',
                'Anda bisa meminta salinan atau penghapusan akun kapan saja',
              ])
                Text(
                  '• $s',
                  style: t.body.copyWith(fontSize: 14, color: c.muted),
                ),
              const SizedBox(height: 4),
              OlButton.text(
                label: 'Baca kebijakan lengkap',
                onPressed: () => context.feedback.sheet<void>(
                  title: 'Kebijakan privasi',
                  message:
                      'Teks kebijakan lengkap disusun bersama klinik sesuai UU PDP No. 27/2022 dan ditampilkan di sini.',
                  actions: const [
                    SheetAction(
                      'Tutup',
                      null,
                      variant: OlButtonVariant.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        item(
          'Penggunaan data kesehatan',
          'Untuk catatan sesi, progres, dan program latihan',
          _health,
          (v) => setState(() => _health = v),
          required: true,
          locked: widget.review,
        ),
        item(
          'Pengingat jadwal via WhatsApp',
          'H-1 sebelum sesi dan konfirmasi booking',
          _reminder,
          (v) => setState(() => _reminder = v),
          required: true,
          locked: widget.review,
        ),
        item(
          'Info promo & tips kesehatan',
          'Opsional · bisa diubah di Profil',
          _promo,
          (v) => setState(() => _promo = v),
        ),
        if (widget.review)
          Text(
            'Untuk mencabut persetujuan data kesehatan, ajukan hapus akun dari Profil.',
            style: t.body.copyWith(fontSize: 14, color: c.muted),
          ),
      ],
    );
  }
}
