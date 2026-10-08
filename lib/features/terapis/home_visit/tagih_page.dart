import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

enum _Method { qris, cash, package, link }

/// TR-10 Tagih di lokasi: tagihan ringkas, QRIS / tunai / paket / link bayar.
/// Terapis tidak bisa menambah diskon atau mengubah harga.
class TagihPage extends StatefulWidget {
  const TagihPage({super.key});

  @override
  State<TagihPage> createState() => _TagihPageState();
}

class _TagihPageState extends State<TagihPage> {
  _Method _method = _Method.qris;
  static const _total = 295000;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Tagih Budi Hartono',
      context_: 'Home visit · check-out 14.36',
      foot: [
        OlButton.secondary(
          label: 'Tagih nanti di klinik',
          onPressed: () {
            context.feedback.info('Tagihan diteruskan ke kasir.');
            Navigator.of(context).maybePop();
          },
        ),
      ],
      children: [
        const OlCard(
          child: Column(
            children: [
              OlMoneyRow(label: 'Relaksasi Premium ±90 mnt', amount: 300000),
              OlMoneyRow(label: 'Ongkos transport · 4,2 km', amount: 25000),
              OlMoneyRow(
                label: 'Diskon member 10%',
                amount: 30000,
                discount: true,
              ),
              OlMoneyTotal(amount: _total),
            ],
          ),
        ),
        const OlOverline('Bayar dengan'),
        OlTwoColumnGrid(
          children: [
            OlOptionTile(
              icon: OlIcons.qris,
              label: 'QRIS',
              selected: _method == _Method.qris,
              onTap: () => setState(() => _method = _Method.qris),
            ),
            OlOptionTile(
              icon: OlIcons.cash,
              label: 'Tunai',
              selected: _method == _Method.cash,
              onTap: () => setState(() => _method = _Method.cash),
            ),
            const OlOptionTile(
              icon: OlIcons.package,
              label: 'Paket',
              subtitle: 'Tidak ada kuota',
              selected: false,
              onTap: null,
            ),
            OlOptionTile(
              icon: OlIcons.send,
              label: 'Link bayar',
              selected: _method == _Method.link,
              onTap: () => setState(() => _method = _Method.link),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: OlMotion.of(context),
          child: switch (_method) {
            _Method.qris => const OlCard(
              key: ValueKey('qris'),
              child: Center(child: QrisPanel(seed: 295)),
            ),
            _Method.cash => OlCard(
              key: const ValueKey('cash'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Terima tunai Rp295.000', style: t.heading),
                  const SizedBox(height: 6),
                  Text(
                    'Uang tunai masuk ke "Kas dibawa" dan diserahkan ke kasir.',
                    style: t.body.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 12),
                  OlButton(
                    label: 'Konfirmasi tunai diterima',
                    onPressed: () {
                      context.feedback.success(
                        'Pembayaran tunai tercatat. Masuk ke Kas dibawa.',
                      );
                      Navigator.of(context).maybePop();
                    },
                  ),
                ],
              ),
            ),
            _Method.link => OlCard(
              key: const ValueKey('link'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Kirim link bayar via WhatsApp', style: t.heading),
                  const SizedBox(height: 6),
                  Text(
                    'Pasien membayar dari HP-nya. Status lunas masuk otomatis.',
                    style: t.body.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 12),
                  OlButton(
                    label: 'Kirim link',
                    icon: OlIcons.send,
                    onPressed: () => context.feedback.success(
                      'Link bayar terkirim ke WhatsApp pasien.',
                    ),
                  ),
                ],
              ),
            ),
            _Method.package => const SizedBox.shrink(),
          },
        ),
        Text(
          'Terapis tidak bisa menambah diskon atau mengubah harga. Tunai yang diterima masuk ke "Kas dibawa".',
          style: t.body.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
