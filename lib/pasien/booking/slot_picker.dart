import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Pilih tanggal (14 hari ke depan) lalu jam kosong dari `GET /v1/slots`.
class SlotPicker extends ConsumerStatefulWidget {
  const SlotPicker({super.key, required this.branchId, required this.serviceId, required this.value, required this.onChanged, this.homeVisit = false});

  final String branchId, serviceId;
  final bool homeVisit;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  ConsumerState<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends ConsumerState<SlotPicker> {
  late DateTime _day = DateUtils.dateOnly(widget.value ?? DateTime.now().add(const Duration(days: 1)));

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = [for (var i = 0; i < 14; i++) today.add(Duration(days: i))];
    final t = context.olText;
    final c = context.ol;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final d in days)
                Padding(
                  padding: const EdgeInsets.only(right: OlSpace.sm),
                  child: OlChip(
                    label: d == today ? 'Hari ini' : Fmt.dayShort(d),
                    selected: d == _day,
                    onTap: () {
                      setState(() => _day = d);
                      widget.onChanged(null);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: OlSpace.md),
        OlAsync<List<SlotV>>(
          key: ValueKey((widget.branchId, widget.serviceId, widget.homeVisit, _day)),
          load: () => ref.read(pasienAppApiProvider).slots(branchId: widget.branchId, serviceId: widget.serviceId, date: _day, homeVisit: widget.homeVisit),
          builder: (context, slots, _) {
            final now = DateTime.now();
            final free = [for (final s in slots) if (s.available && s.start.isAfter(now)) s];
            if (free.isEmpty) {
              return [Text('Tidak ada jam kosong di tanggal ini. Coba tanggal lain.', style: t.body.copyWith(color: c.muted))];
            }
            return [
              Wrap(
                spacing: OlSpace.sm,
                runSpacing: OlSpace.sm,
                children: [
                  for (final s in free)
                    OlChip(
                      label: Fmt.time(s.start.toLocal()),
                      selected: widget.value != null && widget.value!.isAtSameMomentAs(s.start),
                      onTap: () => widget.onChanged(s.start),
                    ),
                ],
              ),
            ];
          },
        ),
      ],
    );
  }
}
