import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Pilih tanggal (14 hari ke depan) lalu jam kosong dari `GET /v1/slots`.
/// Jam dikelompokkan per periode (Pagi/Siang/Sore) dalam tab + grid 4 kolom agar cepat dipilih.
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
  static const _chipW = 56.0, _gap = 8.0;

  late DateTime _day = DateUtils.dateOnly(
    widget.value?.toLocal() ?? DateTime.now().add(const Duration(days: 1)),
  );

  /// Periode jam yang dibuka (Pagi/Siang/Sore). Null = otomatis.
  String? _period;

  late final ScrollController _days = ScrollController(
    // Tanggal terpilih langsung terlihat (mis. kembali dari langkah bayar).
    initialScrollOffset: math.max(
      0,
      _day.difference(DateUtils.dateOnly(DateTime.now())).inDays * (_chipW + _gap) - _chipW,
    ),
  );

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  static String _periodOf(SlotV s) {
    final h = s.start.toLocal().hour;
    return h < 12 ? 'pagi' : (h < 15 ? 'siang' : 'sore');
  }

  static const _periodLabel = {'pagi': 'Pagi', 'siang': 'Siang', 'sore': 'Sore'};

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = [for (var i = 0; i < 14; i++) today.add(Duration(days: i))];
    final t = context.olText;
    final c = context.ol;

    return OlCard(
      padding: const EdgeInsets.fromLTRB(0, OlSpace.lg, 0, OlSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Row(
              children: [
                OlIcon(OlIcons.calendarWeek, size: 20, color: c.brand, weight: OlIconWeight.duotone),
                const SizedBox(width: OlSpace.sm),
                Expanded(child: Text('Pilih tanggal', style: t.heading.copyWith(fontSize: 15))),
                Text(Fmt.monthShort(_day), style: t.caption.copyWith(color: c.muted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: OlSpace.md),
          // Strip tanggal: tergulir di dalam kartu (tidak keluar tepi), sisi kiri/kanan sejajar isi kartu.
          SizedBox(
            height: 72,
            child: ListView.separated(
              controller: _days,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: _gap),
              itemBuilder: (context, i) {
                final d = days[i];
                return _DateCard(
                  weekday: d == today ? 'Hari ini' : Fmt.dayShort(d).split(',').first,
                  dayNumber: '${d.day}',
                  width: _chipW,
                  selected: d == _day,
                  isToday: d == today,
                  onTap: () {
                    if (d == _day) return;
                    HapticFeedback.selectionClick();
                    setState(() {
                      _day = d;
                      _period = null;
                    });
                    widget.onChanged(null);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: OlSpace.md),
          Divider(color: c.line, height: 1),
          const SizedBox(height: OlSpace.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: OlAsync<List<SlotV>>(
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
                                  'Tidak ada jam kosong di tanggal ini. Pilih tanggal lain di atas.',
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

                final byPeriod = <String, List<SlotV>>{};
                for (final s in free) {
                  byPeriod.putIfAbsent(_periodOf(s), () => []).add(s);
                }
                final selectedPeriod = widget.value == null
                    ? null
                    : free.where((s) => s.start.isAtSameMomentAs(widget.value!)).map(_periodOf).firstOrNull;
                final period = byPeriod.containsKey(_period)
                    ? _period!
                    : selectedPeriod ?? byPeriod.keys.first;
                final shown = byPeriod[period]!;

                return [
                  if (byPeriod.length > 1) ...[
                    OlSegmented<String>(
                      segments: {
                        for (final k in _periodLabel.keys)
                          if (byPeriod.containsKey(k)) k: '${_periodLabel[k]} · ${byPeriod[k]!.length}',
                      },
                      value: period,
                      onChanged: (v) => setState(() => _period = v),
                    ),
                    const SizedBox(height: OlSpace.md),
                  ] else ...[
                    Text(
                      '${_periodLabel[period]} · ${shown.length} jam tersedia',
                      style: t.caption.copyWith(color: c.muted, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: OlSpace.sm),
                  ],
                  // 4 kolom ringkas: satu periode muat tanpa menggulir jauh.
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.85,
                    children: [
                      for (final s in shown)
                        _TimeSlotButton(
                          label: Fmt.time(s.start.toLocal()),
                          selected: widget.value != null && widget.value!.isAtSameMomentAs(s.start),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onChanged(s.start);
                          },
                        ),
                    ],
                  ),
                ];
              },
            ),
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
    required this.width,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final String weekday, dayNumber;
  final double width;
  final bool selected, isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Semantics(
      button: true,
      selected: selected,
      label: '$weekday $dayNumber',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: OlMotion.of(context, OlMotion.fast),
          width: width,
          decoration: BoxDecoration(
            color: selected ? c.brandDeep : c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? c.brandDeep : c.line, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekday,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: t.caption.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFFA9D8F2) : (isToday ? c.brand : c.muted),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dayNumber,
                style: t.heading.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : c.fg,
                ),
              ),
              const SizedBox(height: 3),
              // Penanda hari ini: titik kecil (bukan latar berbeda yang mirip "terpilih").
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? (selected ? Colors.white : c.brand) : Colors.transparent,
                ),
              ),
            ],
          ),
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
    return Semantics(
      button: true,
      selected: selected,
      label: 'Jam $label',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: OlMotion.of(context, OlMotion.fast),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.brand : c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? c.brand : c.line, width: 1.5),
            boxShadow: selected ? OlShadow.brandButton : null,
          ),
          child: Text(
            label,
            style: t.mono.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : c.fg,
            ),
          ),
        ),
      ),
    );
  }
}
