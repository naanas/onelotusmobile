import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-11 Konfirmasi pembayaran & struk (§6.4.5): layar sukses, bukan toast.
/// Struk tidak memuat catatan medis.
class StrukPage extends StatelessWidget {
  const StrukPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget row(String l, String v, {bool mono = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l,
                  style: t.body.copyWith(
                    fontSize: 14.5,
                    color: color ?? c.muted,
                  ),
                ),
              ),
              Text(
                v,
                style: (mono ? t.mono : t.body).copyWith(
                  fontSize: 14.5,
                  color: color ?? c.fg,
                ),
              ),
            ],
          ),
        );
    Widget item(String l, String v, {bool discount = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l,
              style: t.body.copyWith(
                fontSize: 14.5,
                color: discount ? c.ok : c.fg,
              ),
            ),
          ),
          Text(
            v,
            style: t.mono.copyWith(
              fontSize: 14.5,
              color: discount ? c.ok : c.fg,
            ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    OlSpace.screen,
                    20,
                    OlSpace.screen,
                    24,
                  ),
                  children: [
                    const Center(
                      child: OlIllustrationImage(
                        OlIllustration.successPayment,
                        width: 200,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        'Pembayaran lunas',
                        textAlign: TextAlign.center,
                        style: t.title.copyWith(fontSize: 26),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rp450.000',
                      textAlign: TextAlign.center,
                      style: t.mono.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Tunai · kembalian '),
                          TextSpan(
                            text: 'Rp50.000',
                            style: t.mono.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.fg,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: t.body.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: SyncIndicator(
                        status: SyncSynced(),
                        label: 'Struk terkirim ke WhatsApp',
                      ),
                    ),
                    const SizedBox(height: 18),
                    OlCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'One Lotus · Klinik Pusat Malang',
                                  style: t.bodyStrong.copyWith(fontSize: 14.5),
                                ),
                              ),
                              Text(
                                'STR-PST-02841',
                                style: t.mono.copyWith(
                                  fontSize: 13,
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Jl. Soekarno-Hatta, Lowokwaru · Sel 6 Okt 2026 11.24',
                            style: t.caption.copyWith(fontSize: 13),
                          ),
                          const Divider(height: 20),
                          row('Pasien', 'Andi Pratama · #0412'),
                          row('Terapis', 'Dimas'),
                          const Divider(height: 16),
                          item('Adjustment Therapy', 'Rp250.000'),
                          item('Masase cedera ringan · 1 titik', 'Rp150.000'),
                          item('Tambahan cedera', 'Rp100.000'),
                          item('Harga member 10%', '-Rp50.000', discount: true),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Total',
                                    style: t.heading.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Rp450.000',
                                  style: t.mono.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          row('Metode', 'Tunai'),
                          row('Poin didapat', '+45 poin', mono: true),
                          row('Kasir', 'Sinta'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Struk tidak memuat catatan medis.',
                      textAlign: TextAlign.center,
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              OlFootBar(
                children: [
                  OlButton(
                    label: 'Selesai',
                    onPressed: () => context.go(Routes.kasirAntrian),
                  ),
                  OlFootRow(
                    children: [
                      OlButton.secondary(
                        label: 'Kirim ulang',
                        onPressed: () => context.feedback.success(
                          'Struk terkirim ke WhatsApp.',
                        ),
                      ),
                      OlButton.secondary(
                        label: 'Cetak',
                        onPressed: () =>
                            context.feedback.info('Mencari printer Bluetooth…'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
