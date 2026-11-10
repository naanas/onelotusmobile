import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Pilih tanggal (14 hari ke depan) dengan kalender strip modern lalu jam kosong dari `GET /v1/slots`.
class SlotPicker extends ConsumerStatefulWidget {
  const SlotPicker({
    super.key,
    required this.branchId,
    required this.serviceId,
    required this.value,
    required this.onChanged,
    this.homeVisit = false,
  });

  final String branchId, serviceId;
  final bool homeVisit;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  ConsumerState<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends ConsumerState<SlotPicker> {
  late DateTime _day = DateUtils.dateOnly(
    widget.value?.toLocal() ?? DateTime.now().add(const Duration(days: 1)),
  );

  String _weekdayShort(DateTime d, DateTime today) {
    if (d == today) return 'Hari ini';
    return Fmt.dayShort(d).split(',').first;
  }

  String _monthShort(DateTime d) {
    final parts = Fmt.dayShort(d).split(' ');
    return parts.isNotEmpty ? parts.last : '';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = [for (var i = 0; i < 14; i++) today.add(Duration(days: i))];
    final t = context.olText;
    final c = context.ol;

    return OlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OlIcon(OlIcons.calendarWeek, size: 20, color: c.brand, weight: OlIconWeight.duotone),
              const SizedBox(width: OlSpace.sm),
              Expanded(
                child: Text(
                  'Pilih Tanggal · ${Fmt.monthShort(_day)}',
                  style: t.heading.copyWith(fontSize: 15),
                ),
              ),
              if (widget.value != null)
                OlTag(
                  Fmt.time(widget.value!.toLocal()),
                  tone: OlTagTone.brand,
                ),
            ],
          ),
          const SizedBox(height: OlSpace.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final (i, d) in days.indexed) ...[
                  if (i > 0) const SizedBox(width: OlSpace.sm),
                  _DateCard(
                    weekday: _weekdayShort(d, today),
                    dayNumber: '${d.day}',
                    month: _monthShort(d),
                    selected: d == _day,
                    isToday: d == today,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _day = d);
                      widget.onChanged(null);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: OlSpace.lg),
          Divider(color: c.line, height: 1),
          const SizedBox(height: OlSpace.md),
          OlAsync<List<SlotV>>(
            key: ValueKey((widget.branchId, widget.serviceId, widget.homeVisit, _day)),
            load: () => ref.read(pasienAppApiProvider).slots(
              branchId: widget.branchId,
              serviceId: widget.serviceId,
              date: _day,
              homeVisit: widget.homeVisit,
            ),
            builder: (context, slots, _) {
              final now = DateTime.now();
              final free = [
                for (final s in slots)
                  if (s.available && s.start.isAfter(now)) s,
              ];
              if (free.isEmpty) {
                return [
                  Container(
                    padding: const EdgeInsets.all(OlSpace.lg),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(OlRadius.input),
                    ),
                    child: Row(
                      children: [
                        OlIcon(OlIcons.clock, color: c.muted, size: 22),
                        const SizedBox(width: OlSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Slot penuh atau klinik tutup', style: t.bodyStrong),
                              const SizedBox(height: 2),
                              Text(
                                'Tidak ada jam kosong di tanggal ini. Silakan geser dan pilih tanggal lain di atas.',
                                style: t.caption.copyWith(color: c.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              }

              final pagi = <SlotV>[];
              final siang = <SlotV>[];
              final sore = <SlotV>[];
              for (final s in free) {
                final h = s.start.toLocal().hour;
                if (h < 12) {
                  pagi.add(s);
                } else if (h < 15) {
                  siang.add(s);
                } else {
                  sore.add(s);
                }
              }

              final groups = <(String, List<SlotV>)>[
                if (pagi.isNotEmpty) ('Pagi', pagi),
                if (siang.isNotEmpty) ('Siang', siang),
                if (sore.isNotEmpty) ('Sore & Malam', sore),
              ];

              return [
                for (final (idx, g) in groups.indexed) ...[
                  if (idx > 0) const SizedBox(height: OlSpace.md),
                  Row(
                    children: [
                      Text(
                        g.$1.toUpperCase(),
                        style: t.overline.copyWith(color: c.muted),
                      ),
                      const SizedBox(width: OlSpace.sm),
                      Text(
                        '(${g.$2.length} slot tersedia)',
                        style: t.caption.copyWith(color: c.faint, fontSize: 11.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: OlSpace.sm),
                  LayoutBuilder(
                    builder: (context, box) {
                      final w = (box.maxWidth - 16) / 3;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in g.$2)
                            SizedBox(
                              width: w,
                              child: _TimeSlotButton(
                                label: Fmt.time(s.start.toLocal()),
                                selected: widget.value != null &&
                                    widget.value!.isAtSameMomentAs(s.start),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  widget.onChanged(s.start);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.weekday,
    required this.dayNumber,
    required this.month,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final String weekday, dayNumber, month;
  final bool selected, isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: OlMotion.of(context, OlMotion.fast),
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? c.brandDeep : (isToday ? c.brandSoft : c.surfaceAlt),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? c.brandDeep
                : (isToday ? c.brand.withValues(alpha: 0.35) : c.line),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? OlShadow.brandButton : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekday,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFFA9D8F2)
                    : (isToday ? c.brand : c.muted),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dayNumber,
              style: t.heading.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : c.fg,
              ),
            ),
            Text(
              month,
              style: t.caption.copyWith(
                fontSize: 11,
                color: selected ? Colors.white70 : c.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSlotButton extends StatelessWidget {
  const _TimeSlotButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: OlMotion.of(context, OlMotion.fast),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.brand : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? c.brand : c.line,
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected ? OlShadow.brandButton : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OlIcon(
               selected ? OlIcons.checkCircle : OlIcons.clock,
              size: 15,
              weight: selected ? OlIconWeight.fill : OlIconWeight.regular,
              color: selected ? Colors.white : c.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: t.mono.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : c.fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
