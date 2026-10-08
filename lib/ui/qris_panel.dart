import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../theme/app_theme.dart';

/// QrisPanel (§4): kode QR besar + status "Menunggu pembayaran" dengan hitung mundur.
/// Saat slicing UI, pola QR dibuat dari [seed] — bukan QRIS sungguhan.
class QrisPanel extends StatefulWidget {
  const QrisPanel({
    super.key,
    required this.seed,
    this.expiresIn = const Duration(minutes: 15),
    this.onExpired,
  });

  final int seed;
  final Duration expiresIn;
  final VoidCallback? onExpired;

  @override
  State<QrisPanel> createState() => _QrisPanelState();
}

class _QrisPanelState extends State<QrisPanel> {
  late Duration _left = widget.expiresIn;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left -= const Duration(seconds: 1));
      if (_left <= Duration.zero) {
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final rnd = Random(widget.seed);
    const n = 9;
    bool finder(int r, int col) =>
        (r < 3 && col < 3) ||
        (r < 3 && col >= n - 3) ||
        (r >= n - 3 && col < 3);
    final expired = _left <= Duration.zero;

    return Column(
      children: [
        Semantics(
          label: 'Kode QRIS untuk dipindai pasien',
          image: true,
          child: Container(
            width: 220,
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.line, width: 1.5),
            ),
            child: Opacity(
              opacity: expired ? 0.15 : 1,
              child: GridView.count(
                crossAxisCount: n,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < n * n; i++)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: finder(i ~/ n, i % n) || rnd.nextBool()
                            ? c.fg
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: expired ? c.critSoft : c.warnSoft,
              borderRadius: BorderRadius.circular(OlRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: expired ? c.crit : c.warn,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  expired ? 'Kode QR kedaluwarsa' : 'Menunggu pembayaran · ',
                  style: t.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: expired ? c.crit : c.warn,
                  ),
                ),
                if (!expired)
                  Text(
                    Fmt.countdown(_left),
                    style: t.mono.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.warn,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
