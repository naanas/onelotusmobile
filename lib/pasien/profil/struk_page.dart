import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// PS-15 Struk digital pasien: bagikan / simpan PDF.
class StrukPasienPage extends StatelessWidget {
  const StrukPasienPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget row(String l, String v, {bool mono = false, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Text(
                l,
                style: bold
                    ? t.bodyStrong.copyWith(fontSize: 16)
                    : t.body.copyWith(color: c.muted),
              ),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Text(
                  v,
                  textAlign: TextAlign.right,
                  style: mono
                      ? t.mono.copyWith(
                          fontSize: bold ? 16 : 14,
                          fontWeight: bold ? FontWeight.w700 : null,
                        )
                      : t.body,
                ),
              ),
            ],
          ),
        );
    Widget dashed() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (_, box) => Row(
          children: [
            for (var i = 0; i < box.maxWidth ~/ 7; i++)
              Container(
                width: 4,
                height: 1,
                margin: const EdgeInsets.only(right: 3),
                color: c.line,
              ),
          ],
        ),
      ),
    );

    return OlDetailScaffold(
      title: 'Struk pembayaran',
      actions: [
        OlIconButton(
          icon: OlIcons.share,
          semanticLabel: 'Bagikan struk',
          onPressed: () => context.feedback.info('Membuka menu bagikan…'),
        ),
      ],
      foot: [
        OlButton.secondary(
          label: 'Simpan sebagai PDF',
          onPressed: () =>
              context.feedback.success('Struk disimpan ke folder Unduhan.'),
        ),
      ],
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: OlLogoMark(size: 40, color: c.brand)),
              const SizedBox(height: 8),
              Text(
                'One Lotus Personal Therapy',
                textAlign: TextAlign.center,
                style: t.heading.copyWith(fontSize: 16),
              ),
              Text(
                'Klinik Pusat Malang · Jl. Soekarno-Hatta No. 9',
                textAlign: TextAlign.center,
                style: t.body.copyWith(fontSize: 13.5, color: c.muted),
              ),
              dashed(),
              row('No. struk', 'STR-PST-02512', mono: true),
              row('Tanggal', 'Sen, 1 Sep 2026 · 10.14'),
              row('Pasien', 'Rina Setiawati · #0387'),
              dashed(),
              Row(
                children: [
                  Expanded(
                    child: Text('Paket Cedera Ringan 5×', style: t.body),
                  ),
                  Text('Rp625.000', style: t.mono.copyWith(fontSize: 14)),
                ],
              ),
              row('Total', 'Rp625.000', mono: true, bold: true),
              row('Metode', 'QRIS · ref 8F21A0'),
              row('Poin didapat', '+62 poin', mono: true),
              row('Kasir', 'Sinta'),
              dashed(),
              Text(
                'Terima kasih. Semoga lekas pulih!',
                textAlign: TextAlign.center,
                style: t.body.copyWith(fontSize: 14, color: c.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
