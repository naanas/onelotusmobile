import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'billing_common.dart';

/// KS-16 Terima kas terapis (home visit, §6.4.7): hitung fisik vs tercatat; selisih wajib catatan (owner diberi tahu).
class TerimaKasPage extends ConsumerStatefulWidget {
  const TerimaKasPage({super.key});

  @override
  ConsumerState<TerimaKasPage> createState() => _TerimaKasPageState();
}

class _TerimaKasPageState extends ConsumerState<TerimaKasPage> {
  int _gen = 0;

  BillingApi get _api => ref.read(billingApiProvider);

  Future<void> _receive(HandoverV h) async {
    var counted = h.amountExpected;
    final note = TextEditingController();
    final ok = await formSheet(
      context,
      title: 'Terima kas ${h.therapistName}',
      message: 'Tercatat ${Fmt.money(h.amountExpected)}. Hitung uang fisik.',
      confirm: 'Terima kas',
      fields: (set) => [
        OlMoneyField(label: 'Uang fisik', value: counted, onChanged: (v) => set(() => counted = v)),
        if (counted != h.amountExpected) OlTextField(label: 'Catatan selisih', controller: note, isRequired: true),
      ],
    );
    if (!ok || !mounted) return;
    final r = await runApi(context, () => _api.receiveCash(h.id, counted, note.text.trim().isEmpty ? null : note.text.trim()));
    if (r == null || !mounted) return;
    context.feedback.success(r.status == 'received_with_diff' ? 'Kas diterima dengan selisih. Owner diberi tahu.' : 'Kas diterima.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Terima kas terapis',
    children: [
      OlAsync<List<HandoverV>>(
        key: ValueKey(_gen),
        load: () => _api.handovers(status: 'handed_over'),
        builder: (context, list, _) {
          final c = context.ol;
          final t = context.olText;
          if (list.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Tidak ada kas diserahkan', message: 'Terapis menyerahkan kas home visit dari menu Kas dibawa.'))];
          }
          return [
            for (final h in list)
              OlCard(
                onTap: () => _receive(h),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.therapistName, style: t.heading),
                          if (h.businessDate != null) Text('Kas ${Fmt.dayShort(h.businessDate!)}', style: t.body.copyWith(color: c.muted)),
                        ],
                      ),
                    ),
                    Text(Fmt.money(h.amountExpected), style: t.bodyStrong),
                    const SizedBox(width: OlSpace.sm),
                    OlIcon(OlIcons.chevronRight, color: c.faint),
                  ],
                ),
              ),
          ];
        },
      ),
    ],
  );
}
