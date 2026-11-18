import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../ui/body_map/body_map.dart';
import '../../ui/body_map/body_map_data.dart';
import '../../ui/ol_button.dart';
import '../../ui/ol_icon.dart';
import '../pasien_routes.dart';

/// Peta tubuh (tampak depan & belakang) di kartu perjalanan pemulihan.
/// Area yang ditangani di sesi terakhir menyala & berdenyut; label progres melayang di atasnya.
/// Tanpa sesi (default pasien baru): siluet dengan garis pindai yang bergerak pelan,
/// label "Menunggu asesmen awal", dan ajakan menjadwalkan sesi pertama.
class RecoveryBody extends StatefulWidget {
  const RecoveryBody({
    super.key,
    required this.areas,
    this.labels = const [],
    this.height = 250,
  });

  /// `slug:sisi` → mode.
  final Map<String, BodyMode> areas;

  /// Label melayang (maks. 2), mis. ("Nyeri berkurang 75%", panah turun). `down == null` = tanpa panah.
  final List<({String text, bool? down})> labels;
  final double height;

  @override
  State<RecoveryBody> createState() => _RecoveryBodyState();
}

class _RecoveryBodyState extends State<RecoveryBody>
    with TickerProviderStateMixin {
  late final Future<BodyMapData> _data = BodyMapData.load();
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OlMotion.reduced(context)) {
      _intro.value = 1;
      _loop.stop();
      _loop.value = .5;
    } else {
      if (!_intro.isAnimating && _intro.value == 0) _intro.forward();
      if (!_loop.isAnimating) _loop.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final empty = widget.areas.isEmpty;
    final labels = widget.labels.isNotEmpty || !empty
        ? widget.labels
        : const [(text: 'Menunggu asesmen awal', down: null)];
    final areaText = BodyMapSelection(widget.areas)
        .chips()
        .map((e) => e.label)
        .join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(OlRadius.input),
            gradient: RadialGradient(
              center: const Alignment(0, -.1),
              radius: .9,
              colors: [c.brandSoft, c.surface],
            ),
          ),
          child: FutureBuilder<BodyMapData>(
            future: _data,
            builder: (context, snap) {
              final d = snap.data;
              if (snap.hasError) {
                return Center(
                  child: OlIcon(OlIcons.body, size: 72, color: BodyColors.outline),
                );
              }
              if (d == null) return const SizedBox.shrink();
              return AnimatedBuilder(
                animation: Listenable.merge([_intro, _loop]),
                builder: (context, _) {
                  final intro = Curves.easeOutCubic.transform(_intro.value);
                  final wave = (math.sin(_loop.value * 2 * math.pi) + 1) / 2;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: intro,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - intro)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: OlSpace.md,
                              ),
                              child: Row(
                                // Tanpa stretch, CustomPaint tanpa anak mendapat tinggi 0 (tak terlihat).
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final v in [d.front, d.back])
                                    Expanded(
                                      child: CustomPaint(
                                        painter: _RecoveryBodyPainter(
                                          view: v,
                                          areas: widget.areas,
                                          wave: wave,
                                          scan: empty ? _loop.value : null,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Label netral (belum ada data): di tengah, di antara kedua siluet.
                      if (labels.length == 1 && labels.first.down == null)
                        Positioned.fill(
                          child: Center(
                            child: Opacity(
                              opacity: intro,
                              child: Transform.translate(
                                offset: Offset(0, wave * 4 - 2),
                                child: _FloatLabel(labels.first.text, down: null),
                              ),
                            ),
                          ),
                        )
                      else
                      for (final (i, label) in labels.take(2).indexed)
                        Positioned(
                          left: i == 0 ? OlSpace.md : null,
                          right: i == 1 ? OlSpace.md : null,
                          top: i == 0 ? widget.height * .2 : null,
                          bottom: i == 1 ? widget.height * .18 : null,
                          child: Opacity(
                            opacity: intro,
                            child: Transform.translate(
                              // Mengambang naik-turun, berlawanan fase antar label.
                              offset: Offset(
                                0,
                                (i == 0 ? wave : 1 - wave) * 4 - 2,
                              ),
                              child: _FloatLabel(label.text, down: label.down),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: OlSpace.sm),
        Text(
          empty
              ? 'Terapis akan menandai area yang ditangani saat sesi pertama. '
                    'Setelah itu progres Anda tampil di sini.'
              : 'Area terapi terakhir: $areaText',
          style: t.caption.copyWith(color: c.muted),
          textAlign: TextAlign.center,
        ),
        if (empty) ...[
          const SizedBox(height: OlSpace.md),
          OlButton.secondary(
            label: 'Jadwalkan sesi pertama',
            icon: OlIcons.calendarPlus,
            onPressed: () => context.go(PRoutes.booking),
          ),
        ],
      ],
    );
  }
}

class _FloatLabel extends StatelessWidget {
  const _FloatLabel(this.text, {required this.down});
  final String text;
  final bool? down;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(OlRadius.pill),
        boxShadow: OlShadow.sh2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (down == null)
            OlIcon(OlIcons.clock, size: 14, color: c.brand)
          else
            Text(
              down! ? '↓' : '↑',
              style: t.caption.copyWith(color: c.ok, fontWeight: FontWeight.w800),
            ),
          const SizedBox(width: 4),
          Text(text, style: t.caption.copyWith(color: c.fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RecoveryBodyPainter extends CustomPainter {
  _RecoveryBodyPainter({
    required this.view,
    required this.areas,
    required this.wave,
    this.scan,
  });

  /// 0..1 posisi garis pindai (hanya saat belum ada data); null = tanpa pindai.
  final double? scan;

  final BodyView view;
  final Map<String, BodyMode> areas;

  /// 0..1 denyut.
  final double wave;

  @override
  void paint(Canvas canvas, Size size) {
    final vb = view.viewBox;
    final s = math.min(size.width / vb.width, size.height / vb.height);
    canvas.save();
    canvas.translate(
      (size.width - vb.width * s) / 2,
      (size.height - vb.height * s) / 2,
    );
    canvas.scale(s);
    canvas.translate(-vb.left, -vb.top);

    canvas.drawPath(view.outline, Paint()..color = BodyColors.silhouette);
    canvas.drawPath(
      view.outline,
      Paint()
        ..color = BodyColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final lit = <BodyMuscle>[];
    for (final m in view.muscles) {
      if (areas.containsKey(m.key)) {
        lit.add(m);
        continue;
      }
      canvas.drawPath(m.path, Paint()..color = BodyColors.base);
      canvas.drawPath(m.path, stroke);
    }

    // Area terapi: cahaya lembut di belakang + warna berdenyut.
    for (final m in lit) {
      final color = BodyColors.of(areas[m.key]);
      canvas.drawPath(
        m.path,
        Paint()
          ..color = color.withValues(alpha: .25 + .25 * wave)
          ..maskFilter = ui.MaskFilter.blur(BlurStyle.normal, 10 + 8 * wave),
      );
    }
    for (final m in lit) {
      final color = BodyColors.of(areas[m.key]);
      canvas.drawPath(
        m.path,
        Paint()..color = color.withValues(alpha: .7 + .3 * wave),
      );
      canvas.drawPath(m.path, stroke);
    }

    if (view.hair != null) {
      canvas.drawPath(view.hair!, Paint()..color = BodyColors.hair);
      canvas.drawPath(view.hair!, stroke);
    }

    // Garis pindai: pita cahaya biru menyapu siluet dari atas ke bawah.
    final sc = scan;
    if (sc != null) {
      final y = vb.top + vb.height * (sc * 1.2 - .1);
      final band = vb.height * .12;
      canvas.save();
      canvas.clipPath(view.outline);
      canvas.drawRect(
        Rect.fromLTRB(vb.left, y - band, vb.right, y + band),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, y - band),
            Offset(0, y + band),
            [
              BodyColors.treated.withValues(alpha: 0),
              BodyColors.treated.withValues(alpha: .28),
              BodyColors.treated.withValues(alpha: 0),
            ],
            [0, .5, 1],
          ),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RecoveryBodyPainter old) =>
      old.wave != wave ||
      old.scan != scan ||
      old.view != view ||
      old.areas != areas;
}
