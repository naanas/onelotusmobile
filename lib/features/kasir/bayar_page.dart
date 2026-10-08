import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Method { qris, cash, transfer, package, points }

/// KS-10 Pembayaran: QRIS (KS-10b), Tunai + CashCalculator (KS-10a), Transfer/VA,
/// Pakai paket → pembayaran gabungan (KS-10c), Poin.
class BayarPage extends StatefulWidget {
  const BayarPage({super.key});

  @override
  State<BayarPage> createState() => _BayarPageState();
}

class _BayarPageState extends State<BayarPage> {
  static const _total = 450000;
  _Method _method = _Method.cash;
  int _received = 500000;
  int _qrSeed = 450;
  bool _busy = false;
  _Method _rest = _Method.cash;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    context.pushReplacement(Routes.kasirStruk);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final change = _received - _total;
    final package = _method == _Method.package;

    return OlDetailScaffold(
      title: package ? 'Pembayaran gabungan' : 'Pembayaran',
      context_: package ? 'Rina Setiawati · #0387' : 'Andi Pratama · #0412',
      titleTrailing: package
          ? null
          : Text(
              Fmt.money(_total),
              style: t.mono.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
            ),
      foot: switch (_method) {
        _Method.cash => [
          OlButton(
            label: 'Konfirmasi pembayaran',
            loading: _busy,
            onPressed: change < 0 ? null : _confirm,
          ),
        ],
        _Method.qris => [
          OlFootRow(
            children: [
              OlButton.secondary(
                label: 'Buat QR baru',
                onPressed: () => setState(() => _qrSeed++),
              ),
              OlButton.secondary(
                label: 'Ganti metode',
                onPressed: () => setState(() => _method = _Method.cash),
              ),
            ],
          ),
        ],
        _Method.transfer => [
          OlButton(
            label: 'Kirim nomor VA ke pasien',
            onPressed: () => context.feedback.success(
              'Nomor VA terkirim ke WhatsApp pasien.',
            ),
          ),
        ],
        _Method.package => [
          OlButton(
            label: 'Bayar sisa Rp85.000 tunai',
            loading: _busy,
            onPressed: _confirm,
          ),
        ],
        _Method.points => [
          OlButton(label: 'Pakai 1.120 poin', onPressed: null),
        ],
      },
      children: [
        OlSegmented<_Method>(
          segments: const {
            _Method.qris: 'QRIS',
            _Method.cash: 'Tunai',
            _Method.transfer: 'Transfer',
            _Method.package: 'Paket',
            _Method.points: 'Poin',
          },
          value: _method,
          onChanged: (v) => setState(() => _method = v),
        ),
        ...switch (_method) {
          _Method.cash => [
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OlMoneyField(
                    label: 'Uang diterima',
                    value: _received,
                    onChanged: (v) => setState(() => _received = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (label, v) in const [
                        ('Pas', _total),
                        ('450rb', 450000),
                        ('500rb', 500000),
                        ('1jt', 1000000),
                      ]) ...[
                        if (label != 'Pas') const SizedBox(width: 8),
                        Expanded(
                          child: OlChip(
                            label: label,
                            expand: true,
                            selected:
                                _received == v &&
                                (label == 'Pas' || v != _total),
                            onTap: () => setState(() => _received = v),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Semantics(
              liveRegion: true,
              label: change < 0
                  ? 'Uang kurang ${Fmt.money(-change)}'
                  : 'Kembalian ${Fmt.money(change)}',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: change < 0 ? c.critSoft : c.okSoft,
                  borderRadius: BorderRadius.circular(OlRadius.card),
                ),
                child: Column(
                  children: [
                    Text(
                      change < 0 ? 'KURANG' : 'KEMBALIAN',
                      style: t.overline.copyWith(
                        color: change < 0 ? c.crit : c.ok,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.money(change.abs()),
                      style: t.mono.copyWith(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: change < 0 ? c.crit : c.ok,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            OlCard(
              child: Column(
                children: [
                  const OlMoneyRow(
                    label: 'Total tagihan',
                    amount: _total,
                    muted: true,
                  ),
                  OlMoneyRow(
                    label: 'Dibayar tunai',
                    amount: _received < _total ? _received : _total,
                    muted: true,
                  ),
                  OlMoneyTotal(
                    label: 'Sisa',
                    amount: (_total - _received).clamp(0, _total),
                  ),
                ],
              ),
            ),
            Text(
              'Tunai tetap bisa dicatat saat offline dan tersinkron otomatis.',
              style: t.body.copyWith(color: c.muted),
            ),
          ],
          _Method.qris => [
            OlCard(
              child: Column(
                children: [
                  Text(
                    'SCAN DENGAN APLIKASI BANK / E-WALLET',
                    style: t.overline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  QrisPanel(key: ValueKey(_qrSeed), seed: _qrSeed),
                  const SizedBox(height: 10),
                  Text(
                    Fmt.money(_total),
                    style: t.mono.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Layar akan berubah otomatis setelah pembayaran diterima. Kecerahan layar dinaikkan.',
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: c.muted),
                  ),
                  // Slicing UI: simulasi status lunas, hanya di build debug.
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    OlButton.text(
                      label: '(Contoh) Simulasikan lunas',
                      onPressed: _confirm,
                    ),
                  ],
                ],
              ),
            ),
            const OlBanner(
              tone: OlBannerTone.warn,
              message: 'Jangan tagih ulang selama status masih menunggu.',
            ),
          ],
          _Method.transfer => [
            const OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OlInfoRow(
                    label: 'Virtual account',
                    value: 'BCA · 8800 1234 0412',
                  ),
                  OlInfoRow(label: 'Nominal', value: 'Rp450.000'),
                  OlInfoRow(label: 'Berlaku sampai', value: '18.00 hari ini'),
                ],
              ),
            ),
            const OlBanner(
              message:
                  'VA cocok otomatis. Transfer manual dengan bukti masuk ke Verifikasi transfer.',
            ),
          ],
          _Method.package => [
            Container(
              padding: const EdgeInsets.all(OlSpace.lg),
              decoration: BoxDecoration(
                color: c.warnSoft,
                borderRadius: BorderRadius.circular(OlRadius.card),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SISA TAGIHAN',
                          style: t.overline.copyWith(color: c.warn),
                        ),
                        Text(
                          'Rp85.000',
                          style: t.mono.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: c.warn,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'dari total',
                        style: t.body.copyWith(color: c.muted),
                      ),
                      Text('Rp235.000', style: t.mono.copyWith(color: c.muted)),
                    ],
                  ),
                ],
              ),
            ),
            const OlOverline('1 · Pakai paket'),
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      OlIcon(
                        OlIcons.package,
                        color: c.ok,
                        weight: OlIconWeight.duotone,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Cedera Ringan 5×', style: t.heading),
                      ),
                      const OlTag('Dipakai', tone: OlTagTone.ok),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const OlMoneyRow(
                    label: 'Masase cedera ringan',
                    amount: 150000,
                    discount: true,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Kuota',
                          style: t.body.copyWith(fontSize: 15, color: c.muted),
                        ),
                      ),
                      Text(
                        '1 → 0 sesi',
                        style: t.mono.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const OlOverline('2 · Biaya di luar paket'),
            const OlCard(
              child: Column(
                children: [
                  OlMoneyRow(label: 'Titik tambahan', amount: 50000),
                  OlMoneyRow(label: 'Kinesio tape', amount: 35000),
                ],
              ),
            ),
            const OlOverline('3 · Bayar sisa dengan'),
            OlSegmented<_Method>(
              segments: const {
                _Method.qris: 'QRIS',
                _Method.cash: 'Tunai',
                _Method.transfer: 'Transfer',
                _Method.points: 'Poin',
              },
              value: _rest,
              onChanged: (v) => setState(() => _rest = v),
            ),
            const OlBanner(
              message:
                  'Paket habis setelah transaksi ini — tawarkan perpanjangan di layar konfirmasi.',
            ),
          ],
          _Method.points => [
            const OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OlInfoRow(label: 'Saldo poin', value: '1.120 poin'),
                  OlInfoRow(label: 'Nilai', value: 'Rp112.000'),
                ],
              ),
            ),
            Text(
              'Poin belum cukup untuk membayar penuh. Saldo: 1.120 poin.',
              style: t.body.copyWith(
                color: c.crit,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        },
      ],
    );
  }
}
