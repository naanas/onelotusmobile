import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  static const _faq = [
    (
      'Kenapa pasien dari form web belum ada di Data Pasien?',
      'Pasien baru dari form web atau aplikasi pasien muncul di tab Formulir. Setujui dulu supaya nomor pasien terbit.',
    ),
    (
      'Booking aplikasi pasien belum muncul di Formulir?',
      'Booking yang memakai pembayaran online baru muncul setelah pasien melunasi pembayarannya.',
    ),
    (
      'Kenapa nomor HP pasien tidak terlihat?',
      'Sama seperti sistem lama, nomor HP pasien hanya bisa dilihat admin.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    const faq = _faq;
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
          'Pertanyaan umum',
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
