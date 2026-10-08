import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-09 Tagihan (tab Kasir): MoneyRow dengan urutan potongan §6.4.4, item tambahan,
/// voucher & diskon (manual wajib alasan), UpsellCard paket, bayar.
class TagihanPage extends StatefulWidget {
  const TagihanPage({super.key});

  @override
  State<TagihanPage> createState() => _TagihanPageState();
}

class _TagihanPageState extends State<TagihanPage> {
  bool _upsell = true;
  int _voucher = 0;
  int _manual = 0;
  final _items = <(String, int)>[
    ('Adjustment Therapy', 250000),
    ('Masase cedera ringan · 1 titik', 150000),
    ('Tambahan cedera', 100000),
  ];

  int get _subtotal => _items.fold(0, (s, i) => s + i.$2);
  int get _member => (_subtotal * 0.1).round();
  int get _total => _subtotal - _member - _voucher - _manual;

  Future<void> _addItem() async {
    final pick = await context.feedback.sheet<(String, int)>(
      title: 'Tambah item',
      message: 'Dari pricelist Klinik Pusat.',
      actions: const [
        SheetAction('Kinesio tape · Rp35.000', (
          'Kinesio tape',
          35000,
        ), variant: OlButtonVariant.secondary),
        SheetAction('Titik tambahan · Rp50.000', (
          'Titik tambahan',
          50000,
        ), variant: OlButtonVariant.secondary),
        SheetAction('Infrared · Rp40.000', (
          'Infrared',
          40000,
        ), variant: OlButtonVariant.secondary),
      ],
    );
    if (pick != null) setState(() => _items.add(pick));
  }

  Future<void> _voucherCode() async {
    final ok = await context.feedback.formSheet<bool>(
      title: 'Pakai voucher',
      builder: (context, close) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OlTextField(
            label: 'Kode voucher',
            initialValue: 'OKTOBERSEHAT',
            mono: true,
          ),
          const SizedBox(height: OlSpace.lg),
          OlButton(label: 'Pakai', onPressed: () => close(true)),
        ],
      ),
    );
    if (ok == true) setState(() => _voucher = 25000);
  }

  Future<void> _discount() async {
    final r = await context.feedback.choose(
      const ConfirmSpec(
        title: 'Diskon manual Rp20.000?',
        message:
            'Diskon manual wajib alasan. Di atas batas tertentu perlu persetujuan owner.',
        confirmLabel: 'Terapkan diskon',
        danger: false,
        reasonLabel: 'Alasan',
      ),
    );
    if (r.confirmed) setState(() => _manual = 20000);
  }

  Future<void> _cancel() async {
    final r = await context.feedback.choose(
      ConfirmSpec(
        title: 'Batalkan tagihan Rp${_total ~/ 1000}.000?',
        message: 'Tagihan jadi Dibatalkan. Sesi tetap tercatat.',
        confirmLabel: 'Batalkan tagihan',
        reasonLabel: 'Alasan',
      ),
    );
    if (r.confirmed && mounted) context.feedback.success('Tagihan dibatalkan.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Column(
      children: [
        Expanded(
          child: OlPageBody(
            header: OlAppHeader(
              title: 'Kasir',
              actions: [
                OlButton.secondary(
                  label: 'Riwayat',
                  small: true,
                  expand: false,
                  onPressed: () => context.push(Routes.kasirRiwayat),
                ),
                const SizedBox(width: 8),
                OlButton.secondary(
                  label: 'Tutup kas',
                  small: true,
                  expand: false,
                  onPressed: () => context.push(Routes.kasirTutupKas),
                ),
              ],
            ),
            children: [
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Andi Pratama',
                                style: t.heading.copyWith(fontSize: 17),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '#0412',
                                      style: t.mono.copyWith(color: c.muted),
                                    ),
                                    const TextSpan(
                                      text: ' · Dimas · Sel 6 Okt 10.30',
                                    ),
                                  ],
                                ),
                                style: t.body.copyWith(color: c.muted),
                              ),
                            ],
                          ),
                        ),
                        OlTag.payment(PaymentStatus.unpaid),
                      ],
                    ),
                    const Divider(height: 20),
                    for (final (l, a) in _items)
                      OlMoneyRow(label: l, amount: a),
                    OlMoneyRow(
                      label: 'Subtotal',
                      amount: _subtotal,
                      muted: true,
                    ),
                    OlMoneyRow(
                      label: '1 · Harga member 10%',
                      amount: _member,
                      discount: true,
                    ),
                    OlMoneyRow(
                      label: '2 · Voucher',
                      amount: _voucher,
                      discount: _voucher > 0,
                      empty: _voucher == 0,
                    ),
                    OlMoneyRow(
                      label: '3 · Diskon manual',
                      amount: _manual,
                      discount: _manual > 0,
                      empty: _manual == 0,
                    ),
                    const OlMoneyRow(label: '4 · Poin Lotus', empty: true),
                    OlMoneyTotal(amount: _total),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OlButton.secondary(
                            label: '+ Item',
                            small: true,
                            onPressed: _addItem,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OlButton.secondary(
                            label: 'Voucher',
                            small: true,
                            onPressed: _voucherCode,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OlButton.secondary(
                            label: 'Diskon',
                            small: true,
                            onPressed: _discount,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // UpsellCard: satu-satunya aksen emas di layar kasir; bisa ditutup.
              AnimatedSize(
                duration: OlMotion.of(context),
                child: !_upsell
                    ? const SizedBox(width: double.infinity)
                    : OlCard(
                        variant: OlCardVariant.gold,
                        onTap: () => context.push(Routes.kasirJualPaket),
                        child: Row(
                          children: [
                            OlIcon(OlIcons.package, color: c.gold),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tawarkan paket 5× Adjustment?',
                                    style: t.bodyStrong.copyWith(
                                      fontSize: 15,
                                      color: c.gold,
                                    ),
                                  ),
                                  Text(
                                    'Hemat Rp125.000 dibanding bayar per sesi',
                                    style: t.body.copyWith(color: c.gold),
                                  ),
                                ],
                              ),
                            ),
                            OlIconButton(
                              icon: OlIcons.close,
                              semanticLabel: 'Tutup tawaran paket',
                              onPressed: () => setState(() => _upsell = false),
                            ),
                          ],
                        ),
                      ),
              ),
              Text(
                'Komisi terapis tercatat otomatis setelah lunas · harga dari pricelist saat sesi.',
                style: t.body.copyWith(color: c.muted),
              ),
            ],
          ),
        ),
        OlFootBar(
          children: [
            OlButton(
              label: 'Bayar Rp${(_total / 1000).round()}.000',
              onPressed: () => context.push(Routes.kasirBayar),
            ),
            OlButton(
              label: 'Batalkan tagihan',
              variant: OlButtonVariant.dangerText,
              expand: true,
              onPressed: _cancel,
            ),
          ],
        ),
      ],
    );
  }
}
