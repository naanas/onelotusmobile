import 'package:flutter/material.dart';

import '../core/format.dart';
import '../theme/app_theme.dart';

/// Satu baris MoneyRow (§4): label kiri, nominal kanan (mono, tabular).
class OlMoneyRow extends StatelessWidget {
  const OlMoneyRow({
    super.key,
    required this.label,
    this.amount,
    this.discount = false,
    this.muted = false,
    this.empty = false,
  });

  final String label;

  /// Rupiah. Diskon ditulis positif, ditampilkan dengan tanda minus & warna `ok`.
  final int? amount;
  final bool discount;
  final bool muted;

  /// Tampilkan "—" (mis. voucher belum dipakai).
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final color = discount ? c.ok : (muted || empty ? c.muted : c.fg);
    final value = empty || amount == null
        ? '—'
        : '${discount ? '-' : ''}${Fmt.money(amount!)}';
    return Semantics(
      label: '$label, ${empty ? 'tidak ada' : value}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: t.body.copyWith(fontSize: 15, color: color),
              ),
            ),
            const SizedBox(width: OlSpace.md),
            Text(value, style: t.mono.copyWith(fontSize: 15, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Garis putus-putus + Total (`.tot`).
class OlMoneyTotal extends StatelessWidget {
  const OlMoneyTotal({super.key, required this.amount, this.label = 'Total'});

  final int amount;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return Semantics(
      label: '$label ${Fmt.money(amount)}',
      excludeSemantics: true,
      child: Column(
        children: [
          const SizedBox(height: 6),
          const _DashedLine(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: t.heading.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                Fmt.money(amount),
                style: t.mono.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter(const Color(0xFFC9D7E2))),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
