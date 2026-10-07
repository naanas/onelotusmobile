import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Blok skeleton dengan shimmer halus (§4). Shimmer mati bila "kurangi gerakan" aktif.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OlMotion.reduced(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFFE5ECF2);
    const hi = Color(0xFFF2F6F9);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final x = _ctrl.value * 3 - 1.5;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(x - 1, 0),
                end: Alignment(x + 1, 0),
                colors: const [base, hi, base],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Kartu skeleton siap pakai (bentuk SessionCard).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(OlSpace.lg),
    decoration: BoxDecoration(
      color: context.ol.surface,
      borderRadius: BorderRadius.circular(OlRadius.card),
      boxShadow: OlShadow.sh1,
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Skeleton(width: 56),
            Spacer(),
            Skeleton(width: 72, height: 22, radius: 999),
          ],
        ),
        SizedBox(height: 12),
        Skeleton(width: 160, height: 16),
        SizedBox(height: 8),
        Skeleton(width: 220),
      ],
    ),
  );
}

/// Daftar skeleton; setelah 1,5 dtk menampilkan "Masih memuat…" (§4).
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 3});

  final int count;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> {
  bool _slow = false;
  late final Timer _timer = Timer(const Duration(milliseconds: 1500), () {
    if (mounted) setState(() => _slow = true);
  });

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat',
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.count; i++) ...[
            if (i > 0) const SizedBox(height: OlSpace.gap),
            const SkeletonCard(),
          ],
          if (_slow) ...[
            const SizedBox(height: OlSpace.md),
            Text(
              'Masih memuat…',
              textAlign: TextAlign.center,
              style: context.olText.caption,
            ),
          ],
        ],
      ),
    );
  }
}
