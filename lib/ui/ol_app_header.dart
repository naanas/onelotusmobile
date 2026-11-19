import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Posisi gulir halaman untuk efek header hero (parallax, judul memudar, lotus menguncup).
/// Dipasang oleh [OlPageBody]; tanpa ini header hero diam.
class OlHeroScroll extends InheritedWidget {
  const OlHeroScroll({super.key, required this.offset, required super.child});

  final ValueListenable<double> offset;

  /// Tanpa dependensi: header tidak dibangun ulang tiap gulir, cukup [AnimatedBuilder] di dalamnya.
  static ValueListenable<double>? maybeOf(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<OlHeroScroll>()?.widget as OlHeroScroll?)?.offset;

  @override
  bool updateShouldNotify(OlHeroScroll old) => old.offset != offset;
}

/// AppHeader (§4): konteks kecil (tanggal · cabang) + judul, aksi di kanan.
/// [hero] = header biru tua beranda (D.5) — kartu pertama menumpuk ke dalamnya.
class OlAppHeader extends StatelessWidget {
  const OlAppHeader({
    super.key,
    required this.title,
    this.context_,
    this.actions = const [],
    this.below,
    this.bottom,
    this.hero = false,
    this.leading,
  });

  final String title;

  /// Teks konteks di atas judul, mis. "Sel, 6 Okt · Klinik Pusat Malang".
  final String? context_;
  final List<Widget> actions;

  /// Widget di bawah aksi kanan (mis. SyncIndicator di header beranda).
  final Widget? below;

  /// Widget selebar penuh di bawah judul (mis. pilihan periode OW-01).
  final Widget? bottom;
  final bool hero;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final fg = hero ? Colors.white : c.fg;
    final ctxColor = hero ? const Color(0xFFA9D8F2) : c.muted;
    final top = MediaQuery.paddingOf(context).top;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        OlSpace.screen,
        top + (hero ? 20 : 18),
        OlSpace.screen,
        hero ? (bottom != null ? 68 : 76) : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: OlSpace.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (context_ != null) ...[
                      Text(
                        context_!,
                        style: t.caption.copyWith(
                          color: ctxColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Semantics(
                      header: true,
                      child: Text(title, style: t.title.copyWith(color: fg)),
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty || below != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (actions.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: actions),
                    if (below != null) ...[const SizedBox(height: 4), below!],
                  ],
                ),
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: OlSpace.lg), bottom!],
        ],
      ),
    );

    if (!hero) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: OlStatusBar.dark,
        child: content,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OlStatusBar.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(OlRadius.heroBottom),
        ),
        child: _HeroScrollLayers(content: content),
      ),
    );
  }
}

/// Lapisan hero yang bereaksi pada gulir: latar bergerak setengah kecepatan (kartu tampak meluncur
/// menutupinya), lotus menguncup, judul memudar + mengecil + naik lebih lambat dari isi.
class _HeroScrollLayers extends StatelessWidget {
  const _HeroScrollLayers({required this.content});
  final Widget content;

  /// Jarak gulir sampai judul hilang penuh.
  static const _fadeRange = 110.0;

  @override
  Widget build(BuildContext context) {
    final scroll = OlMotion.reduced(context) ? null : OlHeroScroll.maybeOf(context);
    if (scroll == null) {
      return Stack(children: [const Positioned.fill(child: OlHeroBackdrop()), content]);
    }
    return Stack(
      children: [
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: scroll,
            builder: (_, o, child) {
              final off = o.clamp(0.0, 600.0);
              return Transform.translate(offset: Offset(0, off * .5), child: OlHeroBackdrop(scroll: off));
            },
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: scroll,
          child: content,
          builder: (_, o, child) {
            final p = (o / _fadeRange).clamp(0.0, 1.0);
            final eased = Curves.easeOut.transform(p);
            return Opacity(
              opacity: 1 - eased,
              child: Transform.translate(
                offset: Offset(0, o.clamp(0.0, 300.0) * .35),
                child: Transform.scale(scale: 1 - .06 * eased, alignment: Alignment.topLeft, child: child),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Latar header hero: gradasi biru tua + cahaya lembut + motif lotus garis tipis dengan riak air.
/// Sisi kiri (tempat judul) paling gelap agar teks putih tetap kontras. Kelopak mekar sekali saat tampil
/// (tanpa animasi bila pengguna mematikan animasi). Dipakai juga (tanpa motif) oleh bar ringkas.
class OlHeroBackdrop extends StatelessWidget {
  const OlHeroBackdrop({super.key, this.motif = true, this.scroll = 0});

  final bool motif;

  /// Jarak gulir (dp): lotus menguncup & sedikit berputar.
  final double scroll;

  static LinearGradient gradient(OlColors c) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(c.brandDeep, Colors.black, .22)!,
      c.brandDeep,
      Color.lerp(c.brandDeep, c.brand, .45)!,
    ],
    stops: const [0, .55, 1],
  );

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final base = DecoratedBox(decoration: BoxDecoration(gradient: gradient(c)));
    if (!motif) return base;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          base,
          TweenAnimationBuilder<double>(
            tween: Tween(begin: OlMotion.reduced(context) ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CustomPaint(painter: _LotusPainter(bloom: v, scroll: scroll)),
          ),
        ],
      ),
    );
  }
}

class _LotusPainter extends CustomPainter {
  _LotusPainter({required double bloom, this.scroll = 0})
    // Digulir → kelopak menutup sampai 45%.
    : bloom = bloom * (1 - .45 * (scroll / 160).clamp(0.0, 1.0)),
      _open = bloom;

  /// 0 = kuncup, 1 = mekar penuh (sudah dikurangi efek gulir).
  final double bloom;
  final double _open;
  final double scroll;

  static const _sky = Color(0xFF38BDF8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;

    // Cahaya kanan atas & kiri bawah.
    void glow(Offset at, double r, double alpha) => canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [_sky.withValues(alpha: alpha), _sky.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
    glow(Offset(w * .92, h * .05), w * .75, .30);
    glow(Offset(w * .02, h * 1.05), w * .55, .10);

    // Lotus: pusat di kanan, sedikit di bawah tengah; sebagian keluar bingkai.
    final base = Offset(w - 100, h * .64);
    final len = (h * .58).clamp(80.0, 140.0);
    final spin = (scroll / 400).clamp(0.0, 1.0) * .35; // putaran halus saat digulir (rad)

    // Riak air di bawah bunga.
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 3; i++) {
      ripple.color = Colors.white.withValues(alpha: (.10 - i * .028) * _open);
      final rw = len * (1.1 + i * .55), rh = len * (.16 + i * .08);
      canvas.drawOval(Rect.fromCenter(center: base.translate(0, len * .06), width: rw * 2, height: rh * 2), ripple);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: .16);
    final fill = Paint()..color = Colors.white.withValues(alpha: .045);

    // Kelopak luar (5) lalu dalam (3): mekar dari tegak ke sudutnya.
    void petal(double angleDeg, double length, double width) {
      final a = angleDeg * bloom * 3.14159265 / 180;
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(a + spin);
      final l = length * (.55 + .45 * bloom);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(-width, -l * .35, -width * .55, -l * .85, 0, -l)
        ..cubicTo(width * .55, -l * .85, width, -l * .35, 0, 0)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
      // Urat tengah kelopak.
      canvas.drawLine(Offset(0, -l * .12), Offset(0, -l * .78), stroke..color = Colors.white.withValues(alpha: .08));
      stroke.color = Colors.white.withValues(alpha: .16);
      canvas.restore();
    }

    for (final d in const [-72.0, 72.0, -40.0, 40.0]) {
      petal(d, len * .78, len * .30);
    }
    for (final d in const [-20.0, 20.0]) {
      petal(d, len * .92, len * .30);
    }
    petal(0, len, len * .32);

    // Titik cahaya kecil.
    final dot = Paint()..color = Colors.white.withValues(alpha: .22 * _open);
    for (final (dx, dy, r) in const [(.58, .22, 1.6), (.70, .12, 1.1), (.50, .55, 1.0), (.78, .40, 1.3)]) {
      canvas.drawCircle(Offset(w * dx, h * dy), r, dot);
    }
  }

  @override
  bool shouldRepaint(_LotusPainter old) => old.bloom != bloom || old.scroll != scroll;
}
