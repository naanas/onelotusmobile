import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

/// Titik indikator PIN (`.pin`).
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.length = 6,
    this.error = false,
  });

  final int filled;
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? context.ol.crit : context.ol.brandDeep;
    return Semantics(
      label: '$filled dari $length digit terisi',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            AnimatedContainer(
              duration: OlMotion.of(context, OlMotion.fast),
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Keypad angka (`.keys`). Tombol kiri bawah opsional (biometrik).
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;

    Widget key(String d) => _Key(
      semanticLabel: d,
      filled: true,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onDigit(d);
            }
          : null,
      child: Text(
        d,
        style: t.title.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          Row(children: [for (final d in row) Expanded(child: key(d))]),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: onBiometric == null
                  ? const SizedBox()
                  : _Key(
                      semanticLabel: 'Buka dengan biometrik',
                      onTap: enabled ? onBiometric : null,
                      child: OlIcon(
                        OlIcons.fingerprint,
                        size: 30,
                        color: c.brand,
                      ),
                    ),
            ),
            Expanded(child: key('0')),
            Expanded(
              child: _Key(
                semanticLabel: 'Hapus satu digit',
                onTap: enabled ? onDelete : null,
                child: Text(
                  'Hapus',
                  style: t.body.copyWith(
                    color: c.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.child,
    required this.semanticLabel,
    required this.onTap,
    this.filled = false,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: Material(
          color: filled ? context.ol.surface : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Ink(
              height: 62,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: filled ? OlShadow.sh1 : null,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
