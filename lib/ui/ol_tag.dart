import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../data/models/status.dart';
import 'ol_icon.dart';

export '../data/models/status.dart';

enum OlTagTone { brand, outline, fill, ok, warn, crit, muted, strike, gold }

/// Tag status berbentuk pil. Selalu teks + warna (status tidak boleh hanya warna, §9).
class OlTag extends StatelessWidget {
  const OlTag(this.label, {super.key, this.tone = OlTagTone.brand, this.icon});

  final String label;
  final OlTagTone tone;
  final OlIconData? icon;

  /// StatusTag siklus sesi (§4, §6.2).
  factory OlTag.session(SessionStatus s, {Key? key}) =>
      OlTag(s.label, key: key, tone: s.tone);

  /// PaymentStatusBadge (§6.4.1).
  factory OlTag.payment(PaymentStatus s, {Key? key, String? detail}) => OlTag(
    detail == null ? s.label : '${s.label} · $detail',
    key: key,
    tone: s.tone,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final (Color bg, Color fg, Border? border) = switch (tone) {
      OlTagTone.brand => (c.brandSoft, c.brandDeep, null),
      OlTagTone.outline => (
        Colors.transparent,
        c.brandDeep,
        Border.all(color: const Color(0xFF9CCDEB), width: 1.5),
      ),
      OlTagTone.fill => (c.brand, Colors.white, null),
      OlTagTone.ok => (c.okSoft, c.ok, null),
      OlTagTone.warn => (c.warnSoft, c.warn, null),
      OlTagTone.crit => (c.critSoft, c.crit, null),
      OlTagTone.muted => (c.surfaceAlt, c.muted, null),
      OlTagTone.strike => (c.surfaceAlt, c.muted, null),
      OlTagTone.gold => (c.goldSoft, c.gold, null),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(OlRadius.pill),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            OlIcon(icon!, size: 14, color: fg, weight: OlIconWeight.duotone),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: context.olText.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: fg,
                decoration: tone == OlTagTone.strike
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Warna tag per status sesi (§4 StatusTag).
extension SessionStatusTone on SessionStatus {
  OlTagTone get tone => switch (this) {
    SessionStatus.awaitingConfirmation => OlTagTone.muted,
    SessionStatus.scheduled => OlTagTone.outline,
    SessionStatus.arrived => OlTagTone.brand,
    SessionStatus.running => OlTagTone.fill,
    SessionStatus.done => OlTagTone.ok,
    SessionStatus.unpaid => OlTagTone.warn,
    SessionStatus.paid => OlTagTone.ok,
    SessionStatus.noShow => OlTagTone.crit,
    SessionStatus.cancelled => OlTagTone.strike,
  };
}

/// Warna PaymentStatusBadge (§6.4.1).
extension PaymentStatusTone on PaymentStatus {
  OlTagTone get tone => switch (this) {
    PaymentStatus.draft || PaymentStatus.expired => OlTagTone.muted,
    PaymentStatus.refundPartial || PaymentStatus.refundFull => OlTagTone.muted,
    PaymentStatus.unpaid ||
    PaymentStatus.pending ||
    PaymentStatus.partial => OlTagTone.warn,
    PaymentStatus.pendingVerify => OlTagTone.brand,
    PaymentStatus.paid => OlTagTone.ok,
    PaymentStatus.failed => OlTagTone.crit,
    PaymentStatus.cancelled => OlTagTone.strike,
  };
}
