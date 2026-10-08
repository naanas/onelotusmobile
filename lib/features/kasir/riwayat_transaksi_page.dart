import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-13 Riwayat transaksi & detail: per hari, filter metode/status/penagih.
class RiwayatTransaksiPage extends StatefulWidget {
  const RiwayatTransaksiPage({super.key});

  @override
  State<RiwayatTransaksiPage> createState() => _RiwayatTransaksiPageState();
}

class _RiwayatTransaksiPageState extends State<RiwayatTransaksiPage> {
  String _filter = 'today';

  static const _rows = [
    ('11.24', 'Andi Pratama', 'Tunai · Sinta', 'Rp450.000', PaymentStatus.paid),
    (
      '11.10',
      'Dewi Lestari',
      'QRIS · Sinta',
      'Rp180.000',
      PaymentStatus.pending,
    ),
    (
      '10.02',
      'Rina Setiawati',
      'Paket + tunai · Sinta',
      'Rp85.000',
      PaymentStatus.paid,
    ),
    (
      '09.15',
      'Ilham Ramadhan',
      'Transfer · refund sebagian',
      'Rp100.000',
      PaymentStatus.refundPartial,
    ),
    (
      '08.40',
      'Yoga Saputra',
      'Paket baru · VA BCA',
      'Rp1.150.000',
      PaymentStatus.paid,
    ),
  ];

  Future<void> _open((String, String, String, String, PaymentStatus) r) async {
    final pick = await context.feedback.sheet<String>(
      title: '${r.$2} · ${r.$4}',
      message: '${r.$1} · ${r.$3} · ${r.$5.label}',
      actions: const [
        SheetAction('Lihat struk', 'struk', variant: OlButtonVariant.secondary),
        SheetAction(
          'Kirim ulang struk',
          'resend',
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Ajukan refund',
          'refund',
          variant: OlButtonVariant.dangerSecondary,
        ),
      ],
    );
    if (!mounted || pick == null) return;
    switch (pick) {
      case 'struk':
        context.push(Routes.kasirStruk);
      case 'resend':
        context.feedback.success('Struk terkirim ke WhatsApp.');
      case 'refund':
        context.push(Routes.kasirRefund);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget kpi(String v, String l, {bool mono = false, Color? color}) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: OlShadow.sh1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v,
                  style: (mono ? t.mono : t.heading).copyWith(
                    fontSize: mono ? 17 : 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(l, style: t.body.copyWith(color: c.muted)),
              ],
            ),
          ),
        );
    Widget chip(String l, String v) => OlChip(
      label: l,
      selected: _filter == v,
      onTap: () => setState(() => _filter = v),
    );

    return OlDetailScaffold(
      title: 'Riwayat transaksi',
      children: [
        Wrap(
          spacing: 8,
          children: [
            chip('Hari ini', 'today'),
            chip('Semua metode', 'method'),
            chip('Semua status', 'status'),
            chip('Penagih', 'by'),
          ],
        ),
        Row(
          children: [
            kpi('Rp3,2 jt', 'omzet', mono: true),
            const SizedBox(width: 10),
            kpi('11', 'transaksi'),
            const SizedBox(width: 10),
            kpi('1', 'menunggu', color: c.warn),
          ],
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, r) in _rows.indexed)
                InkWell(
                  onTap: () => _open(r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: i < _rows.length - 1
                          ? Border(bottom: BorderSide(color: c.line))
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            r.$1,
                            style: t.mono.copyWith(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.$2,
                                style: t.body.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                r.$3,
                                style: t.body.copyWith(color: c.muted),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              r.$4,
                              style: t.mono.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            OlTag(switch (r.$5) {
                              PaymentStatus.pending => 'Menunggu',
                              PaymentStatus.refundPartial => 'Refund',
                              _ => r.$5.label,
                            }, tone: r.$5.tone),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          'Ketuk transaksi untuk detail, kirim ulang struk, atau ajukan refund.',
          style: t.body.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
