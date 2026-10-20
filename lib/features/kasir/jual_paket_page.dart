import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'billing_common.dart';

/// KS-12 Jual paket: pilih paket → tagihan paket → bayar. Paket aktif setelah lunas.
class JualPaketPage extends ConsumerStatefulWidget {
  const JualPaketPage({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<JualPaketPage> createState() => _JualPaketPageState();
}

class _JualPaketPageState extends ConsumerState<JualPaketPage> {
  String? _picked;
  bool _busy = false;

  BillingApi get _api => ref.read(billingApiProvider);

  Future<void> _sell() async {
    final id = _picked;
    if (id == null) return context.feedback.info('Pilih paket.');
    setState(() => _busy = true);
    final inv = await runApi(context, () async {
      final i = await _api.sellPackage(widget.patientId, id);
      return _api.issue(i.id);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (inv != null) context.pushReplacement(Routes.bayar(inv.id));
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Jual paket',
    foot: [OlButton(label: 'Buat tagihan & bayar', loading: _busy, onPressed: _sell)],
    children: [
      OlAsync<List<PackageV>>(
        load: _api.packages,
        builder: (context, list, _) {
          final c = context.ol;
          final t = context.olText;
          final active = [for (final p in list) if (p.isActive) p];
          if (active.isEmpty) {
            return const [
              OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada paket', message: 'Owner menambah paket di Pengaturan → Paket.')),
            ];
          }
          return [
            for (final p in active)
              OlCard(
                onTap: () => setState(() => _picked = p.id),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: t.heading),
                          Text('${p.sessionCount} sesi · berlaku ${p.validDays} hari', style: t.body.copyWith(color: c.muted)),
                          if (p.savings > 0) Text('Hemat ${Fmt.money(p.savings)} dibanding per sesi', style: t.caption.copyWith(color: c.ok)),
                        ],
                      ),
                    ),
                    Text(Fmt.money(p.price), style: t.bodyStrong),
                    const SizedBox(width: OlSpace.sm),
                    OlIcon(_picked == p.id ? OlIcons.checkCircle : OlIcons.check,
                        weight: _picked == p.id ? OlIconWeight.fill : OlIconWeight.regular, color: _picked == p.id ? c.brand : c.line),
                  ],
                ),
              ),
          ];
        },
      ),
    ],
  );
}
