import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Pilih jam baru dari slot server (`GET /v1/slots`) untuk satu sesi: hari (7 hari ke depan) lalu jam.
/// [excludeSessionId] = sesi yang dipindah (tidak dihitung bentrok dengan dirinya).
Future<Slot?> pickSlot(
  BuildContext context, {
  required String title,
  required String branchId,
  required String serviceId,
  String? therapistId,
  String? excludeSessionId,
}) => context.feedback.formSheet<Slot>(
  title: title,
  builder: (ctx, close) => _SlotSheet(
    branchId: branchId,
    serviceId: serviceId,
    therapistId: therapistId,
    excludeSessionId: excludeSessionId,
    onPick: close,
  ),
);

class _SlotSheet extends ConsumerStatefulWidget {
  const _SlotSheet({
    required this.branchId,
    required this.serviceId,
    required this.onPick,
    this.therapistId,
    this.excludeSessionId,
  });

  final String branchId;
  final String serviceId;
  final String? therapistId;
  final String? excludeSessionId;
  final ValueChanged<Slot> onPick;

  @override
  ConsumerState<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends ConsumerState<_SlotSheet> {
  final _days = [
    for (var i = 0; i < 7; i++)
      DateUtils.dateOnly(DateTime.now()).add(Duration(days: i)),
  ];
  late DateTime _day = _days.first;
  int _gen = 0;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OlDayStrip(
        month: DateFormat('MMM', 'id_ID').format(_day),
        days: [
          for (final d in _days)
            OlDay(DateFormat('EEE', 'id_ID').format(d), d.day),
        ],
        selected: _day.day,
        onSelect: (n) => setState(() {
          _day = _days.firstWhere((d) => d.day == n);
          _gen++;
        }),
      ),
      const SizedBox(height: OlSpace.md),
      SizedBox(
        height: 260,
        child: SingleChildScrollView(
          child: OlAsync<List<Slot>>(
            key: ValueKey(_gen),
            load: () => ref
                .read(oneLotusApiProvider)
                .slots(
                  branchId: widget.branchId,
                  date: _day,
                  serviceId: widget.serviceId,
                  therapistId: widget.therapistId,
                  excludeSessionId: widget.excludeSessionId,
                ),
            builder: (context, slots, _) => [
              if (slots.isEmpty)
                Text('Cabang tutup di hari ini.', style: context.olText.body)
              else
                OlSlotPicker(
                  slots: [
                    for (final s in slots)
                      OlSlot(
                        Fmt.time(s.startAt),
                        unavailableLabel: s.available
                            ? null
                            : (s.unavailableReason ?? 'Penuh'),
                      ),
                  ],
                  selected: null,
                  onSelect: (v) => widget.onPick(
                    slots.firstWhere((s) => Fmt.time(s.startAt) == v),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
