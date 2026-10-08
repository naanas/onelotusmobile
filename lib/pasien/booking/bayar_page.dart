import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../demo_data.dart';
import '../pasien_routes.dart';

enum _Method { qris, va, ewallet }

/// PS-09 Pembayaran online (§6.4.2): tagihan belum lunas → pilih metode gateway.
/// Status lunas hanya dari konfirmasi sistem (webhook), bukan dari layar ini.
class BayarPage extends StatefulWidget {
  const BayarPage({
    super.key,
    this.item = 'Titik tambahan · sesi 6 Okt',
    this.amount = 50000,
  });

  final String item;
  final int amount;

  @override
  State<BayarPage> createState() => _BayarPageState();
}

class _BayarPageState extends State<BayarPage> {
  _Method _method = _Method.qris;
  bool _usePoints = false;
  bool _waiting = false;

  int get _discount =>
      _usePoints ? (demoPoints * demoPointValue).clamp(0, widget.amount) : 0;
  int get _total => widget.amount - _discount;

  Future<void> _pay() async {
    setState(() => _waiting = true);
    // Slicing UI: anggap gateway mengonfirmasi lunas setelah jeda singkat.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted || !_waiting) return;
    context.feedback.success('Pembayaran lunas. Struk tersimpan.');
    context.pushReplacement(PRoutes.struk);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    if (_waiting) {
      return OlMessageScreen(
        illustration: OlIllustration.paymentOnline,
        title: 'Menunggu pembayaran',
        message: _method == _Method.qris
            ? 'Pindai QRIS dengan aplikasi bank atau e-wallet Anda. Halaman ini diperbarui otomatis.'
            : 'Selesaikan pembayaran di aplikasi Anda. Halaman ini diperbarui otomatis.',
        foot: [
          OlButton.secondary(
            label: 'Batalkan',
            onPressed: () => setState(() => _waiting = false),
          ),
        ],
        children: [
          if (_method == _Method.qris)
            const Center(child: QrisPanel(seed: 50000)),
        ],
      );
    }

    return OlDetailScaffold(
      title: 'Bayar tagihan',
      foot: [OlButton(label: 'Bayar ${Fmt.money(_total)}', onPressed: _pay)],
      children: [
        OlCard(
          child: Column(
            children: [
              OlMoneyRow(label: widget.item, amount: widget.amount),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Poin Lotus (opsional)',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ),
                  OlButton.text(
                    label: _usePoints
                        ? '-${Fmt.money(_discount)}'
                        : 'Tidak dipakai',
                    onPressed: () => setState(() => _usePoints = !_usePoints),
                  ),
                ],
              ),
              OlMoneyTotal(amount: _total),
            ],
          ),
        ),
        const OlOverline('PILIH METODE'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, (m, icon, title, sub)) in const [
                (_Method.qris, OlIcons.qris, 'QRIS', 'Semua bank & e-wallet'),
                (
                  _Method.va,
                  OlIcons.transfer,
                  'Virtual account',
                  'BCA, BRI, Mandiri, BNI',
                ),
                (
                  _Method.ewallet,
                  OlIcons.phone,
                  'E-wallet',
                  'Dibuka di aplikasi e-wallet Anda',
                ),
              ].indexed)
                Semantics(
                  container: true,
                  inMutuallyExclusiveGroup: true,
                  selected: _method == m,
                  button: true,
                  label: '$title, $sub',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => setState(() => _method = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: i < 2
                            ? Border(bottom: BorderSide(color: c.line))
                            : null,
                      ),
                      child: Row(
                        children: [
                          OlIcon(
                            icon,
                            color: m == _Method.qris ? c.brand : c.muted,
                          ),
                          const SizedBox(width: OlSpace.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: t.body.copyWith(fontSize: 16),
                                ),
                                Text(
                                  sub,
                                  style: t.body.copyWith(color: c.muted),
                                ),
                              ],
                            ),
                          ),
                          _RadioDot(selected: _method == m),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const OlBanner(
          icon: OlIcons.lock,
          message:
              'Pembayaran diproses oleh mitra pembayaran berlisensi. Status lunas dikonfirmasi otomatis oleh sistem.',
        ),
      ],
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});
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
