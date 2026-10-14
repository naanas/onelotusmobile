import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/api/one_lotus_api.dart';
import '../../../data/auth/auth_controller.dart';
import '../../../data/models/models.dart';
import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

typedef _Week = ({
  List<Session> sessions,
  List<TherapistBlock> blocks,
  List<LeaveRequest> leaves,
  Map<String, List<String>> hours,
});

/// TR-02 Jadwal minggu & ketersediaan: grid jam × hari dari jadwal, blok tidak tersedia,
/// dan cuti di server. Mode "Tandai tidak tersedia" membuat/menghapus blok 1 jam
/// (`/v1/therapist-blocks`); jam yang sudah ada sesinya ditolak server.
class JadwalMingguPage extends ConsumerStatefulWidget {
  const JadwalMingguPage({super.key});

  @override
  ConsumerState<JadwalMingguPage> createState() => _JadwalMingguPageState();
}

class _JadwalMingguPageState extends ConsumerState<JadwalMingguPage> {
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _firstHour = 8;
  static const _lastHour = 19;
  int _week = 0;
  bool _marking = false;
  bool _busy = false;
  int _gen = 0;

  DateTime get _monday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today
        .subtract(Duration(days: today.weekday - 1))
        .add(Duration(days: 7 * _week));
  }

  Future<_Week> _load() async {
    final auth = ref.read(authProvider);
    final api = ref.read(oneLotusApiProvider);
    final branch = auth.activeBranch!;
    final from = _monday;
    final r = await (
      api.sessions(
        branchId: branch.id,
        from: from,
        to: from.add(const Duration(days: 7)),
        therapistId: auth.user!.id,
      ),
      api.blocks(),
      api.leaves(mine: true),
      api.branch(branch.id),
    ).wait;
    return (
      sessions: r.$1,
      blocks: r.$2,
      leaves: r.$3,
      hours: r.$4.openingHours,
    );
  }

  void _reload() => setState(() => _gen++);

  bool _overlaps(DateTime a1, DateTime a2, DateTime b1, DateTime b2) =>
      a1.isBefore(b2) && b1.isBefore(a2);

  /// Status satu jam; blok "sekali" yang tepat 1 jam di jam ini dikembalikan agar bisa dihapus.
  (_Slot, TherapistBlock?) _slotAt(_Week w, int col, int hour) {
    final day = _monday.add(Duration(days: col));
    final open = w.hours['${col + 1}'];
    if (open == null || open.length < 2) return (_Slot.closed, null);
    final start = DateTime(day.year, day.month, day.day, hour);
    final end = start.add(const Duration(hours: 1));
    final oh = int.tryParse(open[0].split(':')[0]) ?? 0;
    final ch = int.tryParse(open[1].split(':')[0]) ?? 24;
    if (hour < oh || hour >= ch) return (_Slot.closed, null);
    for (final s in w.sessions) {
      if (s.status == SessionStatus.cancelled ||
          s.status == SessionStatus.noShow) {
        continue;
      }
      if (_overlaps(s.startAt, s.endAt, start, end)) {
        return (s.isHomeVisit ? _Slot.homeVisit : _Slot.session, null);
      }
    }
    for (final l in w.leaves) {
      if (l.status == LeaveStatus.approved &&
          _overlaps(l.startsAt, l.endsAt, start, end)) {
        return (_Slot.unavailable, null);
      }
    }
    for (final b in w.blocks) {
      if (b.kind == 'once' &&
          b.startsAt != null &&
          b.endsAt != null &&
          _overlaps(b.startsAt!, b.endsAt!, start, end)) {
        final exact =
            b.startsAt!.isAtSameMomentAs(start) &&
            b.endsAt!.isAtSameMomentAs(end);
        return (_Slot.unavailable, exact ? b : null);
      }
      if (b.kind == 'weekly' && b.weekday == col + 1) {
        final bs = int.tryParse(b.startTime!.split(':')[0]) ?? 0;
        final be = int.tryParse(b.endTime!.split(':')[0]) ?? 0;
        final bem = int.tryParse(b.endTime!.split(':')[1]) ?? 0;
        if (hour >= bs && (hour < be || (hour == be && bem > 0))) {
          return (_Slot.unavailable, null);
        }
      }
    }
    return (_Slot.free, null);
  }

  Future<void> _tap(_Week w, int col, int hour) async {
    final (slot, block) = _slotAt(w, col, hour);
    final label = '${_days[col]} ${hour.toString().padLeft(2, '0')}.00';
    if (!_marking) {
      context.feedback.info(switch (slot) {
        _Slot.session => '$label · sesi terjadwal',
        _Slot.homeVisit => '$label · home visit',
        _Slot.unavailable => '$label · tidak tersedia',
        _Slot.free => '$label · kosong',
        _Slot.closed => '$label · cabang tutup',
      });
      return;
    }
    if (_busy || slot == _Slot.closed) return;
    if (slot == _Slot.session || slot == _Slot.homeVisit) {
      context.feedback.info(
        'Jam ini sudah ada sesi. Minta kasir memindahkan sesi dulu.',
      );
      return;
    }
    if (slot == _Slot.unavailable && block == null) {
      context.feedback.info(
        'Jam ini tidak tersedia karena cuti atau blok mingguan.',
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    final api = ref.read(oneLotusApiProvider);
    final day = _monday.add(Duration(days: col));
    final start = DateTime(day.year, day.month, day.day, hour);
    try {
      if (block != null) {
        await api.deleteBlock(block.id);
      } else {
        await api.createBlock(
          kind: 'once',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 1)),
        );
      }
      _reload();
    } on AppError catch (e) {
      if (!mounted) return;
      final msg = e.fieldError('starts_at') ?? e.fieldError('ends_at');
      if (msg != null) {
        context.feedback.info(msg);
      } else {
        context.feedback.error(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final monday = _monday;
    final sunday = monday.add(const Duration(days: 6));
    final today = DateTime.now();
    return OlDetailScaffold(
      title: _week == 0 ? 'Jadwal minggu ini' : 'Jadwal minggu depan',
      actions: [
        OlIconButton(
          icon: OlIcons.back,
          semanticLabel: 'Minggu sebelumnya',
          onPressed: _week == 0 ? null : () => setState(() => _week--),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${monday.day}–${Fmt.dateNoDay(sunday)}',
            style: t.bodyStrong.copyWith(fontSize: 15),
          ),
        ),
        OlIconButton(
          icon: OlIcons.chevronRight,
          semanticLabel: 'Minggu berikutnya',
          onPressed: _week == 1 ? null : () => setState(() => _week++),
        ),
      ],
      foot: [
        OlFootRow(
          children: [
            OlButton.secondary(
              label: _marking ? 'Selesai menandai' : 'Tandai tidak tersedia',
              onPressed: () {
                setState(() => _marking = !_marking);
                if (_marking) {
                  context.feedback.info(
                    'Ketuk jam kosong untuk menandai tidak tersedia; ketuk lagi untuk membatalkan.',
                  );
                }
              },
            ),
            OlButton(
              label: 'Ajukan cuti',
              onPressed: () async {
                await context.push(Routes.terapisAjukanCuti);
                _reload();
              },
            ),
          ],
        ),
      ],
      children: [
        Wrap(
          spacing: OlSpace.sm,
          runSpacing: OlSpace.sm,
          children: [
            _Legend(color: c.brand, label: 'Sesi'),
            const _Legend(color: Color(0xFFF2B263), label: 'Home visit'),
            const _Legend(striped: true, label: 'Tidak tersedia'),
          ],
        ),
        OlAsync<_Week>(
          key: ValueKey('$_week-$_gen'),
          load: _load,
          builder: (context, w, _) => [
            OlCard(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 30),
                      for (final (i, d) in _days.indexed)
                        Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: t.body.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    DateUtils.isSameDay(
                                      monday.add(Duration(days: i)),
                                      today,
                                    )
                                    ? c.brand
                                    : c.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (var h = _firstHour; h <= _lastHour; h++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              h.toString().padLeft(2, '0'),
                              style: t.mono.copyWith(color: c.muted),
                            ),
                          ),
                          for (var col = 0; col < 7; col++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: _Cell(
                                  slot: _slotAt(w, col, h).$1,
                                  label: '${_days[col]} jam $h',
                                  onTap: () => _tap(w, col, h),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            for (final l in w.leaves)
              if (l.status != LeaveStatus.cancelled &&
                  l.endsAt.isAfter(DateTime.now()))
                OlCard(
                  child: Row(
                    children: [
                      OlTag(
                        l.status.label,
                        tone: switch (l.status) {
                          LeaveStatus.approved => OlTagTone.ok,
                          LeaveStatus.rejected => OlTagTone.crit,
                          _ => OlTagTone.warn,
                        },
                      ),
                      const SizedBox(width: OlSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cuti ${Fmt.dateNoDay(l.startsAt)}'
                              '${l.allDay && l.endsAt.difference(l.startsAt).inDays > 1 ? ' – ${Fmt.dateNoDay(l.endsAt.subtract(const Duration(days: 1)))}' : ''}',
                              style: t.heading,
                            ),
                            Text(
                              '${l.reason} · ${l.affectedSessions} sesi terdampak',
                              style: t.body.copyWith(color: c.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, this.color, this.striped = false});
  final String label;
  final Color? color;
  final bool striped;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: context.ol.surface,
      borderRadius: BorderRadius.circular(OlRadius.pill),
      border: Border.all(color: context.ol.line, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 14,
          child: striped
              ? CustomPaint(painter: _StripePainter(radius: 4))
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(label, style: context.olText.body.copyWith(fontSize: 14.5)),
      ],
    ),
  );
}

enum _Slot { session, homeVisit, unavailable, free, closed }

class _Cell extends StatelessWidget {
  const _Cell({required this.slot, required this.label, required this.onTap});
  final _Slot slot;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final radius = BorderRadius.circular(9);
    final status = switch (slot) {
      _Slot.session => 'sesi',
      _Slot.homeVisit => 'home visit',
      _Slot.unavailable => 'tidak tersedia',
      _Slot.free => 'kosong',
      _Slot.closed => 'cabang tutup',
    };
    return Semantics(
      container: true,
      button: true,
      label: '$label, $status',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: OlMotion.of(context, OlMotion.fast),
          height: 34,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: switch (slot) {
              _Slot.session => c.brand,
              _Slot.homeVisit => const Color(0xFFF2B263),
              _Slot.unavailable => const Color(0xFFE3EBF2),
              _Slot.free => const Color(0xFFE9F1F8),
              _Slot.closed => Colors.transparent,
            },
          ),
          child: slot == _Slot.unavailable
              ? ClipRRect(
                  borderRadius: radius,
                  child: CustomPaint(painter: _StripePainter()),
                )
              : null,
        ),
      ),
    );
  }
}

/// Arsiran diagonal "tidak tersedia".
class _StripePainter extends CustomPainter {
  _StripePainter({this.radius = 0});
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    canvas.drawRect(rect, Paint()..color = const Color(0xFFE3EBF2));
    final p = Paint()
      ..color = const Color(0xFFB7C7D4)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
}
