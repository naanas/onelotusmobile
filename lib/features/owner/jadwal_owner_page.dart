import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Cell {
  done,
  running,
  arrived,
  scheduled,
  homeVisit,
  late,
  leave,
  empty,
  rest,
}

typedef _Slot = ({String? name, _Cell kind, String? note});

const _therapists = ['Dimas', 'Fajar', 'Laras'];
const _hours = ['09', '10', '12', '13', '15'];

/// Grid contoh OW-02 (baris = jam, kolom = terapis).
const _grid = <List<_Slot>>[
  [
    (name: 'Rina S.', kind: _Cell.done, note: null),
    (name: 'Yoga S.', kind: _Cell.scheduled, note: null),
    (name: null, kind: _Cell.empty, note: null),
  ],
  [
    (name: 'Andi P.', kind: _Cell.running, note: null),
    (name: null, kind: _Cell.empty, note: null),
    (name: 'Dewi L.', kind: _Cell.arrived, note: null),
  ],
  [
    (name: null, kind: _Cell.rest, note: null),
    (name: null, kind: _Cell.rest, note: null),
    (name: null, kind: _Cell.rest, note: null),
  ],
  [
    (name: 'Budi H.', kind: _Cell.homeVisit, note: null),
    (name: 'Hendra G.', kind: _Cell.scheduled, note: null),
    (name: null, kind: _Cell.empty, note: null),
  ],
  [
    (name: 'Sari W.', kind: _Cell.late, note: null),
    (name: 'Lestari K.', kind: _Cell.scheduled, note: null),
    (name: 'Cuti', kind: _Cell.leave, note: '15.00–17.00'),
  ],
];

/// OW-02 Jadwal semua terapis (tab Jadwal owner): grid harian per terapis,
/// ringkasan mingguan, tambah & pindahkan sesi.
class JadwalOwnerPage extends StatefulWidget {
  const JadwalOwnerPage({super.key});

  @override
  State<JadwalOwnerPage> createState() => _JadwalOwnerPageState();
}

class _JadwalOwnerPageState extends State<JadwalOwnerPage> {
  bool _week = false;

  Future<void> _openSlot(String therapist, String hour, _Slot s) async {
    if (s.kind == _Cell.rest) return;
    if (s.kind == _Cell.empty) {
      final ok = await context.feedback.sheet<bool>(
        title: 'Slot kosong',
        message: '$therapist · $hour.00',
        actions: const [SheetAction('Buat sesi di slot ini', true)],
      );
      if (ok == true && mounted) context.push(Routes.kasirBuatJadwal);
      return;
    }
    await context.feedback.sheet<void>(
      title: s.name!,
      message: '$therapist · $hour.00 · ${_label(s)}',
      actions: const [
        SheetAction('Tutup', null, variant: OlButtonVariant.secondary),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlPageBody(
      header: OlAppHeader(
        title: 'Jadwal terapis',
        context_: 'Sel, 6 Okt · Klinik Pusat Malang',
        actions: [
          OlButton(
            label: '+ Sesi',
            small: true,
            expand: false,
            onPressed: () => context.push(Routes.kasirBuatJadwal),
          ),
        ],
      ),
      children: [
        OlSegmented<bool>(
          segments: const {false: 'Hari', true: 'Minggu'},
          value: _week,
          onChanged: (v) => setState(() => _week = v),
        ),
        AnimatedSwitcher(
          duration: OlMotion.of(context),
          child: _week
              ? const _WeekTable(key: ValueKey('week'))
              : OlCard(
                  key: const ValueKey('day'),
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 34),
                          for (final (i, th) in _therapists.indexed)
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    th,
                                    style: t.bodyStrong.copyWith(fontSize: 15),
                                  ),
                                  Text(
                                    '${const [6, 5, 4][i]} sesi',
                                    style: t.body.copyWith(
                                      fontSize: 13.5,
                                      color: c.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final (r, hour) in _hours.indexed)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 34,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      hour,
                                      style: t.mono.copyWith(
                                        fontSize: 13.5,
                                        color: c.muted,
                                      ),
                                    ),
                                  ),
                                ),
                                for (final (i, s) in _grid[r].indexed)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: _SlotCell(
                                        slot: s,
                                        tall: s.kind == _Cell.homeVisit,
                                        onTap: () =>
                                            _openSlot(_therapists[i], hour, s),
                                        semanticLabel:
                                            '${_therapists[i]} jam $hour: ${s.name ?? (s.kind == _Cell.rest ? 'istirahat' : 'kosong')}${s.name == null ? '' : ', ${_label(s)}'}',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Okupansi hari ini ',
                  children: [
                    TextSpan(
                      text: '78%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.fg,
                      ),
                    ),
                    const TextSpan(text: ' · geser untuk terapis lain'),
                  ],
                ),
                style: t.body.copyWith(color: c.muted),
              ),
            ),
            OlButton.text(
              label: 'Pindahkan sesi',
              expand: false,
              onPressed: () => context.push(Routes.kasirPindahMassal),
            ),
          ],
        ),
      ],
    );
  }
}

String _label(_Slot s) => switch (s.kind) {
  _Cell.done => 'Selesai',
  _Cell.running => 'Berjalan',
  _Cell.arrived => 'Hadir',
  _Cell.scheduled => 'Dijadwalkan',
  _Cell.homeVisit => 'Home visit',
  _Cell.late => 'Terlambat',
  _Cell.leave => s.note ?? 'Cuti',
  _Cell.empty || _Cell.rest => '',
};

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.slot,
    required this.onTap,
    required this.semanticLabel,
    this.tall = false,
  });

  final _Slot slot;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    const radius = BorderRadius.all(Radius.circular(12));

    if (slot.kind == _Cell.rest) {
      return Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: ClipRRect(
          borderRadius: radius,
          child: const SizedBox(
            height: 40,
            child: CustomPaint(painter: _StripePainter()),
          ),
        ),
      );
    }

    final (bg, fg, border) = switch (slot.kind) {
      _Cell.done => (c.okSoft, c.ok, null),
      _Cell.running => (c.brand, Colors.white, null),
      _Cell.homeVisit => (c.warnSoft, c.warn, null),
      _Cell.late => (c.brandSoft, c.warn, const Color(0xFFF6B26B)),
      _Cell.leave => (c.critSoft, c.crit, null),
      _Cell.empty => (c.surfaceAlt, c.muted, const Color(0xFFC5D3DE)),
      _ => (c.brandSoft, c.brandDeep, null),
    };
    final nameColor = switch (slot.kind) {
      _Cell.running => Colors.white,
      _Cell.leave => c.fg,
      _ => c.fg,
    };

    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: border == null
              ? BorderSide.none
              : BorderSide(color: border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: tall ? 116 : 80),
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            alignment: Alignment.topLeft,
            child: slot.name == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(
                          fontSize: 14.5,
                          color: nameColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Satu kata per baris, mengecil bila kolom sempit.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _label(slot),
                          style: t.body.copyWith(fontSize: 13.5, color: fg),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8EFF5),
    );
    final p = Paint()
      ..color = const Color(0xFFC5D3DE)
      ..strokeWidth = 5;
    for (var x = -size.height; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
}

/// Ringkasan mingguan: jumlah sesi per terapis per hari.
class _WeekTable extends StatelessWidget {
  const _WeekTable({super.key});

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  static const _counts = [
    [7, 6, 5, 7, 6, 8],
    [5, 5, 6, 4, 5, 7],
    [4, 4, 0, 5, 4, 6],
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget cell(String s, {TextStyle? style, bool left = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        s,
        textAlign: left ? TextAlign.left : TextAlign.center,
        style: style,
      ),
    );
    return OlCard(
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.6)},
        children: [
          TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line)),
            ),
            children: [
              cell('TERAPIS', style: t.overline, left: true),
              for (final d in _days) cell(d, style: t.overline),
            ],
          ),
          for (final (i, th) in _therapists.indexed)
            TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.line)),
              ),
              children: [
                cell(th, style: t.body.copyWith(fontSize: 15), left: true),
                for (final n in _counts[i])
                  cell(
                    n == 0 ? 'Cuti' : '$n',
                    style: n == 0
                        ? t.body.copyWith(fontSize: 12, color: c.crit)
                        : t.mono.copyWith(fontSize: 14),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
