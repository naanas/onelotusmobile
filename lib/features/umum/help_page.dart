import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_controller.dart';
import '../../data/models/staff_user.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-15 Bantuan & kebijakan: FAQ per peran, kontak, dokumen.
class HelpPage extends ConsumerStatefulWidget {
  const HelpPage({super.key});

  @override
  ConsumerState<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends ConsumerState<HelpPage> {
  int? _open = 0;

  static const _faq = {
    Role.terapis: [
      (
        'Bagaimana jika sinyal hilang saat rekam sesi?',
        'Catatan tetap tersimpan di HP dan terkirim otomatis saat sinyal kembali. Lihat status di Akun › Status sinkron.',
      ),
      (
        'Kapan catatan sesi tidak bisa diedit?',
        'Pembuat bisa mengedit sampai batas waktu setelah sesi. Setelah itu tambahkan addendum — catatan asli tetap utuh.',
      ),
      (
        'Cara check-in home visit di luar radius',
        'Ketuk Check-in, lalu tulis alasannya. Owner bisa meninjau check-in di luar radius.',
      ),
    ],
    Role.kasir: [
      (
        'Pembayaran QRIS tidak berubah jadi lunas?',
        'Status lunas hanya dari konfirmasi server. Jangan tagih ulang — tunggu atau cek di riwayat transaksi.',
      ),
      (
        'Bagaimana jika tunai diterima saat offline?',
        'Pembayaran tunai tetap bisa dicatat dan terkirim saat sinyal kembali.',
      ),
    ],
    Role.owner: [
      (
        'Di mana menyetujui cuti & refund?',
        'Semua permintaan ada di Persetujuan, badge jumlahnya tampil di tab Ringkasan.',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final role =
        ref.watch(authProvider.select((s) => s.activeRole)) ?? Role.terapis;
    final faq = _faq[role]!;
    Widget doc(String title, {String? trailing, bool divider = true}) =>
        OlListItem(
          title: title,
          trailing: trailing == null
              ? null
              : Text(trailing, style: t.body.copyWith(color: c.muted)),
          divider: divider,
          onTap: () => context.feedback.info('Membuka $title…'),
        );

    return OlDetailScaffold(
      title: 'Bantuan & kebijakan',
      children: [
        OlOverline(
          'Pertanyaan umum · ${role == Role.kasir ? 'kasir' : role.label.toLowerCase()}',
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, (q, a)) in faq.indexed)
                Container(
                  decoration: BoxDecoration(
                    border: i < faq.length - 1
                        ? Border(bottom: BorderSide(color: c.line))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        container: true,
                        button: true,
                        expanded: _open == i,
                        label: q,
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _open = _open == i ? null : i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    q,
                                    style: t.body.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: _open == i ? 0 : -0.25,
                                  duration: OlMotion.of(context, OlMotion.fast),
                                  child: OlIcon(
                                    OlIcons.chevronDown,
                                    size: 20,
                                    color: c.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: OlMotion.of(context),
                        curve: OlMotion.curve,
                        alignment: Alignment.topCenter,
                        child: _open == i
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  a,
                                  style: t.body.copyWith(color: c.muted),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const OlOverline('Hubungi'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              OlListItem(
                leading: OlIcon(OlIcons.chat, color: c.brand),
                title: 'Admin klinik',
                subtitle: 'Chat WhatsApp jam kerja',
                onTap: () => context.feedback.info('Membuka WhatsApp…'),
              ),
              OlListItem(
                leading: OlIcon(OlIcons.settings, color: c.brand),
                title: 'Dukungan teknis VELTECH',
                subtitle: 'Laporkan masalah aplikasi',
                divider: false,
                onTap: () => context.feedback.info('Membuka formulir laporan…'),
              ),
            ],
          ),
        ),
        const OlOverline('Dokumen'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              doc('Kebijakan privasi', trailing: 'UU PDP No. 27/2022'),
              doc('Syarat penggunaan'),
              OlListItem(
                title: 'Lisensi open source',
                divider: false,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'One Lotus',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
