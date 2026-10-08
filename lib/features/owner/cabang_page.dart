import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// OW-17 Cabang & ruang: alamat + titik peta, radius check-in home visit,
/// transport per km, jam operasional, daftar ruang.
class CabangPage extends StatefulWidget {
  const CabangPage({super.key});

  @override
  State<CabangPage> createState() => _CabangPageState();
}

class _CabangPageState extends State<CabangPage> {
  String _branch = 'Klinik Pusat Malang';
  int _radius = 200;
  int _transport = 6000;
  final _rooms = ['Ruang 1', 'Ruang 2', 'Ruang 3 · adjustment'];
  final _hours = [
    ('Senin–Jumat', '08.00–20.00'),
    ('Sabtu', '08.00–17.00'),
    ('Minggu', null),
  ];

  Future<void> _switchBranch() async {
    final b = await context.feedback.sheet<String>(
      title: 'Pilih cabang',
      actions: [
        for (final b in const ['Klinik Pusat Malang', 'Cabang Batu'])
          SheetAction(
            b,
            b,
            variant: b == _branch
                ? OlButtonVariant.primary
                : OlButtonVariant.secondary,
          ),
      ],
    );
    if (b != null) setState(() => _branch = b);
  }

  Future<void> _addRoom() async {
    final name = await context.feedback.formSheet<String>(
      title: 'Ruang baru',
      builder: (ctx, close) {
        var v = 'Ruang ${_rooms.length + 1}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OlTextField(
              label: 'Nama ruang',
              initialValue: v,
              onChanged: (s) => v = s,
            ),
            const SizedBox(height: OlSpace.lg),
            OlButton(
              label: 'Tambah ruang',
              onPressed: () {
                if (v.trim().isNotEmpty) close(v.trim());
              },
            ),
          ],
        );
      },
    );
    if (name != null) setState(() => _rooms.add(name));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: _branch,
      titleTrailing: OlButton.text(label: 'Ganti', onPressed: _switchBranch),
      foot: [
        OlButton(
          label: 'Simpan cabang',
          onPressed: () => context.feedback.success('$_branch disimpan.'),
        ),
      ],
      children: [
        OlTextField(
          key: ValueKey('addr-$_branch'),
          label: 'Alamat',
          isRequired: true,
          initialValue: _branch.startsWith('Klinik')
              ? 'Jl. Soekarno-Hatta No. 9, Lowokwaru'
              : 'Jl. Diponegoro No. 21, Batu',
        ),
        Semantics(
          label: 'Titik lokasi cabang dengan radius check-in $_radius meter',
          image: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(OlRadius.card),
            child: SizedBox(
              height: 112,
              width: double.infinity,
              child: CustomPaint(
                painter: _PinMapPainter(
                  bg: const Color(0xFFDCEAF3),
                  road: Colors.white,
                  ring: c.brand,
                  radius: _radius,
                ),
              ),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OlTextField(
                label: 'Radius check-in',
                initialValue: '$_radius',
                mono: true,
                suffixText: 'm',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) =>
                    setState(() => _radius = int.tryParse(v) ?? _radius),
              ),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: OlMoneyField(
                label: 'Transport / km',
                large: false,
                value: _transport,
                onChanged: (v) => setState(() => _transport = v),
              ),
            ),
          ],
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Jam operasional', style: t.heading.copyWith(fontSize: 16)),
              const SizedBox(height: 6),
              for (final (day, h) in _hours)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(day, style: t.body.copyWith(fontSize: 15)),
                      ),
                      Text(
                        h ?? 'Tutup',
                        style: h == null
                            ? t.body.copyWith(color: c.muted)
                            : t.mono.copyWith(fontSize: 14.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ruang',
                      style: t.heading.copyWith(fontSize: 16),
                    ),
                  ),
                  OlButton.text(label: '+ Ruang', onPressed: _addRoom),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [for (final r in _rooms) OlChip(label: r)],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinMapPainter extends CustomPainter {
  const _PinMapPainter({
    required this.bg,
    required this.road,
    required this.ring,
    required this.radius,
  });

  final Color bg;
  final Color road;
  final Color ring;
  final int radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final roadPaint = Paint()
      ..color = road
      ..strokeWidth = 10;
    canvas.drawLine(
      Offset(0, size.height * 0.62),
      Offset(size.width, size.height * 0.45),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.45, 0),
      Offset(size.width * 0.49, size.height),
      roadPaint,
    );
    final center = Offset(size.width * 0.48, size.height * 0.53);
    // Skala tampilan: 200 m ≈ 40 px, dibatasi agar tetap di dalam peta.
    final r = (radius / 5).clamp(14.0, size.height * 0.48);
    canvas.drawCircle(center, r, Paint()..color = ring.withValues(alpha: 0.12));
    final dash = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const n = 36;
    for (var i = 0; i < n; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        i * 2 * math.pi / n,
        2 * math.pi / n,
        false,
        dash,
      );
    }
    // Pin.
    final pin = Path()
      ..moveTo(center.dx, center.dy)
      ..cubicTo(
        center.dx - 18,
        center.dy - 16,
        center.dx - 12,
        center.dy - 34,
        center.dx,
        center.dy - 34,
      )
      ..cubicTo(
        center.dx + 12,
        center.dy - 34,
        center.dx + 18,
        center.dy - 16,
        center.dx,
        center.dy,
      );
    canvas.drawPath(pin, Paint()..color = ring);
    canvas.drawPath(
      pin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PinMapPainter old) => old.radius != radius;
}
