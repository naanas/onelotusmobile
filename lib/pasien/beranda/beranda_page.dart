import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../demo_data.dart';
import '../pasien_routes.dart';

/// PS-05 Beranda pasien (§5.8): progres pemulihan, tagihan, latihan hari ini,
/// sesi berikutnya, poin, paket hampir habis, Booking ulang.
class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  String _greeting() {
    final h = DateTime.now().hour;
    return h < 11
        ? 'Selamat pagi'
        : h < 15
        ? 'Selamat siang'
        : h < 18
        ? 'Selamat sore'
        : 'Selamat malam';
  }

  void _toggle(DemoExercise e) {
    setState(() => e.doneAt = e.done ? null : Fmt.time(DateTime.now()));
    if (e.done) context.feedback.success('${e.name} selesai. Hebat!');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlPageBody(
      heroOverlap: true,
      header: OlAppHeader(
        hero: true,
        title: '${_greeting()}, Rina',
        context_: 'One Lotus',
        actions: [
          OlIconButton(
            icon: OlIcons.bell,
            semanticLabel: 'Notifikasi, 1 baru',
            badge: 1,
            onHero: true,
            onPressed: () => context.push(PRoutes.notifikasi),
          ),
        ],
      ),
      children: [
        const FeedbackBannerHost(),
        OlCard(
          onTap: () => context.push(PRoutes.riwayat),
          semanticLabel:
              'Pemulihan ankle kiri 72 persen. Nyeri turun dari 8 ke 2 dalam 6 sesi.',
          child: Row(
            children: [
              const _Ring(value: 0.72),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pemulihan ankle kiri', style: t.heading),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        text: 'Nyeri turun dari ',
                        children: [
                          const TextSpan(
                            text: '8',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: ' ke '),
                          TextSpan(
                            text: '2',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: c.brand,
                            ),
                          ),
                          const TextSpan(
                            text: ' dalam 6 sesi. Teruskan latihannya!',
                          ),
                        ],
                      ),
                      style: t.body.copyWith(fontSize: 14.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _WarnCard(
          title: 'Tagihan belum lunas',
          message: 'Titik tambahan sesi 6 Okt · Rp50.000',
          actionLabel: 'Bayar',
          onAction: () => context.push(PRoutes.bayar),
        ),
        OlSectionHeader(
          title: 'Latihan hari ini',
          actionLabel: 'Semua',
          onAction: () => context.go(PRoutes.latihan),
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, e) in demoExercises.indexed)
                Container(
                  decoration: BoxDecoration(
                    border: i < demoExercises.length - 1
                        ? Border(bottom: BorderSide(color: c.line))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OlCheckbox(
                          label: '${e.name} · ${e.dose}',
                          value: e.done,
                          strikeWhenChecked: true,
                          onChanged: (_) => _toggle(e),
                        ),
                      ),
                      if (!e.done)
                        Semantics(
                          container: true,
                          button: true,
                          label: 'Buka ${e.name}',
                          excludeSemantics: true,
                          child: InkResponse(
                            radius: 24,
                            onTap: () =>
                                context.push(PRoutes.latihanDetail(e.id)),
                            child: SizedBox.square(
                              dimension: OlSize.minTouch,
                              child: Center(
                                child: OlIcon(
                                  OlIcons.chevronRight,
                                  size: 20,
                                  color: c.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        OlCard(
          onTap: () => context.push(PRoutes.jadwal),
          semanticLabel:
              'Sesi berikutnya Kamis 8 Oktober pukul 16.00, masase cedera ringan bersama Dimas. Sisa paket 1 sesi.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OlOverline('SESI BERIKUTNYA'),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: 'Kamis, 8 Okt · ',
                  children: [
                    TextSpan(
                      text: '16.00',
                      style: t.mono.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                style: t.heading.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Masase cedera ringan · Dimas · Klinik Pusat Malang',
                style: t.body.copyWith(fontSize: 14, color: c.muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const OlTag('Sisa paket 1 sesi', tone: OlTagTone.warn),
                  OlButton.text(
                    label: 'Ubah jadwal',
                    onPressed: () => context.push(PRoutes.ubahJadwal),
                  ),
                ],
              ),
            ],
          ),
        ),
        OlCard(
          variant: OlCardVariant.gold,
          onTap: () => context.push(PRoutes.poin),
          semanticLabel:
              '$demoPoints poin Lotus, senilai ${Fmt.money(demoPoints * demoPointValue)}',
          child: Row(
            children: [
              OlIcon(
                OlIcons.points,
                color: c.gold,
                weight: OlIconWeight.duotone,
              ),
              const SizedBox(width: OlSpace.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$demoPoints poin Lotus',
                    style: t.mono.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.warn,
                    ),
                  ),
                  Text(
                    'senilai ${Fmt.money(demoPoints * demoPointValue)}',
                    style: t.body.copyWith(color: c.warn),
                  ),
                ],
              ),
            ],
          ),
        ),
        OlCard(
          onTap: () => context.push(PRoutes.beliPaket),
          semanticLabel:
              'Paket hampir habis. Perpanjang dan hemat hingga Rp350.000',
          child: Row(
            children: [
              OlIcon(OlIcons.package, color: c.brand),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paket hampir habis', style: t.bodyStrong),
                    Text(
                      'Perpanjang dan hemat hingga Rp350.000',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        OlButton(
          label: 'Booking ulang',
          onPressed: () => context.go(PRoutes.booking),
        ),
      ],
    );
  }
}

/// Kartu peringatan dengan tombol di kanan (tagihan belum lunas).
class _WarnCard extends StatelessWidget {
  const _WarnCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      padding: const EdgeInsets.all(OlSpace.lg),
      decoration: BoxDecoration(
        color: c.warnSoft,
        borderRadius: BorderRadius.circular(OlRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.bodyStrong.copyWith(fontSize: 16, color: c.warn),
                ),
                Text(message, style: t.body.copyWith(color: c.warn)),
              ],
            ),
          ),
          const SizedBox(width: OlSpace.sm),
          OlButton(
            label: actionLabel,
            small: true,
            expand: false,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

/// Lingkar progres pemulihan dengan angka di tengah.
class _Ring extends StatelessWidget {
  const _Ring({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: OlMotion.of(context, const Duration(milliseconds: 700)),
        curve: OlMotion.curve,
        builder: (context, v, _) => SizedBox.square(
          dimension: 92,
          child: CustomPaint(
            painter: _RingPainter(v, c.brand, c.surfaceAlt),
            child: Center(
              child: Text(
                '${(v * 100).round()}%',
                style: context.olText.display.copyWith(fontSize: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value, this.color, this.track);
  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 11.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(w / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      p..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
