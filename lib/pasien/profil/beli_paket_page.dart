import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

/// PS-14 Beli / perpanjang paket via gateway. Paket aktif setelah pembayaran dikonfirmasi sistem.
class BeliPaketPage extends ConsumerStatefulWidget {
  const BeliPaketPage({super.key});

  @override
  ConsumerState<BeliPaketPage> createState() => _BeliPaketPageState();
}

class _BeliPaketPageState extends ConsumerState<BeliPaketPage> {
  String? _picked;
  bool _busy = false;

  Future<void> _buy() async {
    final api = ref.read(pasienAppApiProvider);
    setState(() => _busy = true);
    final inv = await runApi(context, () => api.buyPackage(_picked!));
    if (!mounted) return;
    setState(() => _busy = false);
    if (inv != null) context.pushReplacement('${PRoutes.bayar}?invoice=${inv.id}');
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Beli paket',
    foot: [OlButton(label: 'Lanjut bayar', loading: _busy, onPressed: _picked == null ? null : _buy)],
    children: [
      OlAsync<List<PackageV>>(
        load: () async => [for (final p in (await ref.read(pasienAppApiProvider).catalog()).packages) if (p.isActive) p],
        builder: (context, list, _) {
          final c = context.ol;
          final t = context.olText;
          if (list.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada paket', message: 'Tanyakan paket terapi ke klinik.'))];
          }
          return [
            for (final p in list)
              OlCard(
                variant: _picked == p.id ? OlCardVariant.now : OlCardVariant.plain,
                onTap: () => setState(() => _picked = p.id),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: t.heading),
                          Text('${p.sessionCount} sesi · berlaku ${p.validDays} hari', style: t.body.copyWith(color: c.muted)),
                          if (p.savings > 0) Text('Hemat ${Fmt.money(p.savings)}', style: t.bodyStrong.copyWith(color: c.ok)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Fmt.money(p.price), style: t.bodyStrong),
                        if (_picked == p.id) OlIcon(OlIcons.checkCircle, color: c.brand),
                      ],
                    ),
                  ],
                ),
              ),
            Text('Paket aktif otomatis setelah pembayaran dikonfirmasi.', style: t.caption.copyWith(color: c.muted)),
          ];
        },
      ),
    ],
  );
}
