import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

sealed class SyncStatus {
  const SyncStatus();
}

class SyncSynced extends SyncStatus {
  const SyncSynced();
}

class SyncSaving extends SyncStatus {
  const SyncSaving();
}

class SyncOffline extends SyncStatus {
  const SyncOffline(this.pending);
  final int pending;
}

class SyncFailed extends SyncStatus {
  const SyncFailed(this.failed);
  final int failed;
}

/// SyncIndicator (§4): Tersinkron · Menyimpan… · Offline — n catatan menunggu · Gagal sinkron.
/// Ketuk → detail (UM-14 / bottom sheet ST-07).
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({
    super.key,
    required this.status,
    this.onTap,
    this.onHero = false,
    this.label,
  });

  final SyncStatus status;
  final VoidCallback? onTap;

  /// Varian di atas header hero gelap (`.hd.hero .sync`).
  final bool onHero;

  /// Ganti teks default (mis. TR-04: "Tersimpan di HP · sinkron otomatis").
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final (String text, Color bg, Color fg, Color heroFg) = switch (status) {
      SyncSynced() => ('Tersinkron', c.okSoft, c.ok, const Color(0xFFD9F99D)),
      SyncSaving() => (
        'Menyimpan…',
        c.surfaceAlt,
        c.muted,
        const Color(0xFFE0F2FE),
      ),
      SyncOffline(:final pending) => (
        pending > 0 ? 'Offline — $pending catatan menunggu' : 'Offline',
        c.warnSoft,
        c.warn,
        const Color(0xFFFDE68A),
      ),
      SyncFailed() => (
        'Gagal sinkron',
        c.critSoft,
        c.crit,
        const Color(0xFFFECACA),
      ),
    };
    final color = onHero ? heroFg : fg;
    final shown = label ?? text;

    return Semantics(
      container: true,
      button: onTap != null,
      label: 'Status sinkron: $shown',
      excludeSemantics: true,
      child: Material(
        color: onHero ? Colors.white.withValues(alpha: 0.14) : bg,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status is SyncSaving && !OlMotion.reduced(context))
                  SizedBox.square(
                    dimension: 9,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: color,
                    ),
                  )
                else
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.22),
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    shown,
                    style: context.olText.caption.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
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
