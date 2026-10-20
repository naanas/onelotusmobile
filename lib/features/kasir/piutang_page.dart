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

/// KS-18 Piutang (tagihan belum lunas): pilih pasien → kirim pengingat WA massal. Pengingat sejenis maks 1×/7 hari.
class PiutangPage extends ConsumerStatefulWidget {
  const PiutangPage({super.key});

  @override
  ConsumerState<PiutangPage> createState() => _PiutangPageState();
}

class _PiutangPageState extends ConsumerState<PiutangPage> {
  final _picked = <String>{};
  int _gen = 0;
  bool _busy = false;

  BillingApi get _api => ref.read(billingApiProvider);

  Future<void> _remind() async {
    setState(() => _busy = true);
    final ok = await runApi(context, () => _api.remind(_picked.toList()).then((_) => true));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok == true) {
        _picked.clear();
        _gen++;
      }
    });
    if (ok == true) context.feedback.success('Pengingat diantre. Pasien yang sudah diingatkan 7 hari terakhir dilewati.');
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Piutang',
    foot: [
      if (_picked.isNotEmpty) OlButton(label: 'Kirim pengingat (${_picked.length})', icon: OlIcons.send, loading: _busy, onPressed: _remind),
    ],
    children: [
      OlAsync<List<ReceivableV>>(
        key: ValueKey(_gen),
        load: () async => (await _api.receivables()).items,
        builder: (context, list, _) {
          if (list.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Tidak ada piutang', message: 'Semua tagihan sudah lunas.'))];
          }
          final total = list.fold(0, (s, r) => s + r.balance);
          return [
            OlCard(child: OlMoneyRow(label: '${list.length} tagihan belum lunas', amount: total)),
            OlCard(
              padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
              child: Column(
                children: [
                  for (final r in list)
                    Row(
                      children: [
                        Expanded(
                          child: OlCheckbox(
                            label: r.patientName,
                            subtitle: [
                              '${Fmt.money(r.balance)} · ${r.ageDays} hari',
                              if (r.lastRemindedAt != null) 'diingatkan ${Fmt.dayShort(r.lastRemindedAt!)}',
                            ].join(' · '),
                            value: _picked.contains(r.invoiceId),
                            onChanged: (v) => setState(() => v ? _picked.add(r.invoiceId) : _picked.remove(r.invoiceId)),
                          ),
                        ),
                        OlIconButton(
                          icon: OlIcons.chevronRight,
                          semanticLabel: 'Buka tagihan ${r.patientName}',
                          onPressed: () => context.push(Routes.kasirTagihan(r.invoiceId)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ];
        },
      ),
    ],
  );
}
