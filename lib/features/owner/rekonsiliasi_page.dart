import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';

const _statusLabels = {'matched': 'Cocok', 'mismatch': 'Selisih', 'unsettled': 'Belum cair', 'checked': 'Sudah dicek'};

/// OW-19 Rekonsiliasi gateway (QRIS & VA): settlement per hari vs sistem; selisih dicek owner dengan catatan.
class RekonsiliasiPage extends ConsumerStatefulWidget {
  const RekonsiliasiPage({super.key});

  @override
  ConsumerState<RekonsiliasiPage> createState() => _RekonsiliasiPageState();
}

class _RekonsiliasiPageState extends ConsumerState<RekonsiliasiPage> {
  String? _status = 'mismatch';
  int _gen = 0;

  Future<void> _check(SettlementV s) async {
    final r = await context.feedback.choose(
      ConfirmSpec(
        title: 'Tandai sudah dicek?',
        message: '${s.ref} · ${Fmt.money(s.gross)}. Tulis hasil pengecekan.',
        confirmLabel: 'Tandai dicek',
        reasonLabel: 'Catatan',
      ),
    );
    if (!r.confirmed || !mounted) return;
    final ok = await runApi(context, () => ref.read(billingApiProvider).checkSettlement(s.id, r.reason ?? ''));
    if (ok == null || !mounted) return;
    context.feedback.success('Ditandai sudah dicek.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Rekonsiliasi',
    children: [
      OlSegmented<String?>(
        segments: const {'mismatch': 'Selisih', 'unsettled': 'Belum cair', null: 'Semua'},
        value: _status,
        onChanged: (v) => setState(() => _status = v),
      ),
      OlAsync<List<SettlementV>>(
        key: ValueKey((_status, _gen)),
        load: () => ref.read(billingApiProvider).settlements(status: _status),
        builder: (context, list, _) {
          final c = context.ol;
          final t = context.olText;
          if (list.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Tidak ada data', message: 'Settlement gateway diimpor otomatis setiap hari.'))];
          }
          return [
            for (final s in list)
              OlCard(
                onTap: s.status == 'mismatch' ? () => _check(s) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s.ref.isEmpty ? '-' : s.ref, style: t.bodyStrong)),
                        OlTag(
                          _statusLabels[s.status] ?? s.status,
                          tone: switch (s.status) {
                            'matched' || 'checked' => OlTagTone.ok,
                            'mismatch' => OlTagTone.crit,
                            _ => OlTagTone.warn,
                          },
                        ),
                      ],
                    ),
                    if (s.date != null) Text(Fmt.date(s.date!), style: t.caption.copyWith(color: c.muted)),
                    const SizedBox(height: OlSpace.sm),
                    OlMoneyRow(label: 'Bruto', amount: s.gross),
                    OlMoneyRow(label: 'MDR', amount: s.mdr, discount: true, empty: s.mdr == 0),
                    OlMoneyRow(label: 'Bersih', amount: s.net),
                    if (s.note != null) Text('"${s.note}"', style: t.caption.copyWith(color: c.muted)),
                  ],
                ),
              ),
          ];
        },
      ),
    ],
  );
}
