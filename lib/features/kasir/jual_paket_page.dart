import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-12 Jual paket / membership. Harga & isi paket = contoh mockup (aturan paket: workshop §16).
class JualPaketPage extends StatefulWidget {
  const JualPaketPage({super.key});

  @override
  State<JualPaketPage> createState() => _JualPaketPageState();
}

class _JualPaketPageState extends State<JualPaketPage> {
  static const _packages = [
    (
      'Cedera Ringan 5×',
      '5 sesi masase cedera ringan · berlaku 60 hari',
      625000,
      125000,
    ),
    ('Cedera Ringan 10×', '10 sesi · berlaku 120 hari', 1150000, 350000),
    (
      'Adjustment 5×',
      '5 sesi Adjustment Therapy · berlaku 60 hari',
      1125000,
      125000,
    ),
  ];
  int _picked = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final price = _packages[_picked].$3;
    return OlDetailScaffold(
      title: 'Jual paket',
      context_: 'Untuk Rina Setiawati · #0387',
      foot: [
        OlButton(
          label: 'Lanjut bayar ${Fmt.money(price)}',
          onPressed: () => context.push(Routes.kasirBayar),
        ),
      ],
      children: [
        const OlBanner(
          tone: OlBannerTone.warn,
          message:
              'Paket Cedera Ringan masih sisa 1 sesi. Paket baru akan mulai setelah kuota lama habis.',
        ),
        for (final (i, (name, desc, p, save)) in _packages.indexed)
          Semantics(
            container: true,
            button: true,
            inMutuallyExclusiveGroup: true,
            checked: _picked == i,
            label: '$name, $desc, ${Fmt.money(p)}, hemat ${Fmt.money(save)}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _picked = i);
              },
              child: AnimatedContainer(
                duration: OlMotion.of(context, OlMotion.fast),
                padding: const EdgeInsets.all(OlSpace.lg),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(OlRadius.card),
                  border: Border.all(
                    color: _picked == i ? c.brand : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: _picked == i
                      ? [BoxShadow(color: c.brandSoft, spreadRadius: 4)]
                      : OlShadow.sh1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: t.heading.copyWith(fontSize: 17),
                          ),
                        ),
                        _RadioDot(selected: _picked == i),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(desc, style: t.body.copyWith(color: c.muted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Fmt.money(p),
                            style: t.mono.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OlTag('Hemat ${Fmt.money(save)}', tone: OlTagTone.ok),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: OlTextField(
                label: 'Mulai berlaku',
                initialValue: 'Setelah kuota lama',
                enabled: false,
              ),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: OlTextField(
                label: 'Voucher',
                hint: 'Kode voucher',
                onChanged: (_) {},
              ),
            ),
          ],
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
      width: 26,
      height: 26,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? c.brand : const Color(0xFF8A9AA8),
          width: selected ? 2 : 1.5,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? c.brand : Colors.transparent,
        ),
      ),
    );
  }
}
