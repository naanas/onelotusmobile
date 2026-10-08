import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../demo_data.dart';
import '../pasien_routes.dart';

/// PS-14 Beli / perpanjang paket via gateway. Poin opsional sebagai potongan.
class BeliPaketPage extends StatefulWidget {
  const BeliPaketPage({super.key});

  @override
  State<BeliPaketPage> createState() => _BeliPaketPageState();
}

class _BeliPaketPageState extends State<BeliPaketPage> {
  String _pick = 'cr10';
  bool _usePoints = false;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final p = demoPackages.firstWhere((e) => e.id == _pick);
    final pointsValue = demoPoints * demoPointValue;
    final total = p.price - (_usePoints ? pointsValue : 0);

    return OlDetailScaffold(
      title: 'Pilih paket',
      context_: 'Klinik Pusat Malang',
      foot: [
        OlButton(
          label: 'Beli · ${Fmt.money(total)}',
          onPressed: () => context.push(PRoutes.bayar),
        ),
      ],
      children: [
        for (final x in demoPackages)
          _PackageCard(
            package: x,
            selected: x.id == _pick,
            onTap: () => setState(() => _pick = x.id),
          ),
        OlCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pakai $demoPoints poin', style: t.bodyStrong),
                    Text(
                      'Potongan ${Fmt.money(pointsValue)}',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              OlToggle(
                value: _usePoints,
                semanticLabel: 'Pakai $demoPoints poin',
                onChanged: (v) => setState(() => _usePoints = v),
              ),
            ],
          ),
        ),
        Text(
          'Paket baru aktif setelah sisa 1 sesi paket lama terpakai.',
          style: t.body.copyWith(fontSize: 14, color: c.muted),
        ),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final DemoPackage package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final p = package;
    final radius = BorderRadius.circular(OlRadius.card);
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label:
          '${p.name}${p.best ? ', paling hemat' : ''}. ${p.detail}. ${Fmt.money(p.price)}${p.saving == null ? '' : ', hemat ${Fmt.money(p.saving!)}'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: OlMotion.of(context, OlMotion.fast),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? c.brand : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: c.brand.withValues(alpha: 0.14),
                    spreadRadius: 4,
                  ),
                ]
              : OlShadow.sh1,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(OlSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              p.name,
                              style: t.heading.copyWith(fontSize: 17),
                            ),
                            if (p.best)
                              const OlTag('Paling hemat', tone: OlTagTone.fill),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Radio(selected: selected),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(p.detail, style: t.body.copyWith(color: c.muted)),
                  const SizedBox(height: 8),
                  // Harga & label hemat turun ke baris baru bila tak muat.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        Fmt.money(p.price),
                        style: t.mono.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (p.saving != null)
                        OlTag(
                          'Hemat ${Fmt.money(p.saving!)}',
                          tone: OlTagTone.ok,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
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
