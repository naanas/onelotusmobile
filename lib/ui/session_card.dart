import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/models/models.dart';
import '../theme/app_theme.dart';
import 'ol_button.dart';
import 'ol_card.dart';
import 'ol_icon.dart';
import 'ol_tag.dart';

/// Kartu sesi (§4 SessionCard). Sesi berjalan: kartu "now" + tombol rekam sesi.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.now,
    this.nextUp = false,
    this.forTherapist = true,
    this.onTap,
    this.onOpenRecord,
    this.onStart,
    this.startBlockedReason,
    this.onMore,
  });

  final Session session;
  final DateTime now;

  /// Sesi berikutnya → keterangan "berikutnya dalam n mnt" (§5.1).
  final bool nextUp;

  /// Terapis melihat "Selesai" untuk sesi yang sudah ditangani (status bayar urusan kasir).
  final bool forTherapist;
  final VoidCallback? onTap;
  final VoidCallback? onOpenRecord;

  /// Tombol "Mulai sesi" untuk sesi berstatus Hadir.
  final VoidCallback? onStart;

  /// Bila diisi, tombol Mulai nonaktif dan alasan ini tampil di bawahnya.
  final String? startBlockedReason;

  /// Menu ⋯ (tidak datang, minta pindah jadwal, home visit).
  final VoidCallback? onMore;

  bool get _running => session.status == SessionStatus.running;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final s = session;
    final onDark = _running;
    final capColor = onDark ? const Color(0xFFCDE9F9) : c.muted;
    final status = forTherapist && s.isFinished ? SessionStatus.done : s.status;

    return OlCard(
      variant: onDark ? OlCardVariant.now : OlCardVariant.plain,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      onTap: onTap,
      semanticLabel: _semantic(status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                Fmt.time(s.startAt),
                style: t.mono.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: onDark ? Colors.white : c.fg,
                ),
              ),
              const SizedBox(width: OlSpace.sm),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (s.isHomeVisit)
                      const OlTag(
                        'Home visit',
                        tone: OlTagTone.warn,
                        icon: OlIcons.homeVisit,
                      ),
                    if (s.isNewPatient)
                      const OlTag('Pasien baru', tone: OlTagTone.outline),
                    if (_running)
                      _RunningTag(startedAt: s.startedAt ?? s.startAt, now: now)
                    else
                      OlTag.session(status),
                  ],
                ),
              ),
              if (onMore != null)
                SizedBox(
                  width: 36,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Aksi lain untuk ${s.patientName}',
                    onPressed: onMore,
                    icon: OlIcon(
                      OlIcons.more,
                      size: 20,
                      color: onDark ? Colors.white : c.muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.patientName,
            style: t.heading.copyWith(color: onDark ? Colors.white : c.fg),
          ),
          const SizedBox(height: 2),
          Text(_caption(), style: t.body.copyWith(color: capColor)),
          if (s.isLateAt(now)) ...[
            const SizedBox(height: 10),
            _LateBanner(minutes: now.difference(s.startAt).inMinutes),
          ],
          if (_running && onOpenRecord != null) ...[
            const SizedBox(height: 12),
            _WhiteButton(label: 'Buka rekam sesi', onPressed: onOpenRecord!),
          ],
          if (!_running &&
              onStart != null &&
              s.status == SessionStatus.arrived) ...[
            const SizedBox(height: 12),
            OlButton(
              label: 'Mulai sesi',
              icon: OlIcons.clock,
              small: true,
              onPressed: startBlockedReason == null ? onStart : null,
            ),
            if (startBlockedReason != null) ...[
              const SizedBox(height: 6),
              Text(startBlockedReason!, style: t.caption),
            ],
          ],
        ],
      ),
    );
  }

  String _caption() {
    final s = session;
    final parts = <String>[];
    if (s.note != null && !s.isHomeVisit) {
      parts.add(s.note!);
    } else {
      parts.add(
        s.isHomeVisit
            ? '${s.serviceName} ±${s.durationMin} mnt'
            : s.serviceName,
      );
      final hv = s.homeVisit;
      if (hv != null) {
        final area = hv.address.split(',').last.trim();
        parts.add(
          hv.distanceKm == null ? area : '$area, ${_km(hv.distanceKm!)}',
        );
      } else if (s.room != null) {
        parts.add(s.room!);
      }
    }
    if (nextUp) {
      parts.add('berikutnya dalam ${_until(s.startAt.difference(now))}');
    }
    return parts.join(' · ');
  }

  static String _km(double km) =>
      '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

  static String _until(Duration d) {
    final m = d.inMinutes;
    if (m < 60) return '$m mnt';
    final h = m ~/ 60;
    return '$h jam';
  }

  String _semantic(SessionStatus status) {
    final s = session;
    return [
      'Jam ${Fmt.time(s.startAt)}',
      s.patientName,
      _caption(),
      if (s.isHomeVisit) 'Home visit',
      if (s.isNewPatient) 'Pasien baru',
      _running ? 'Berjalan' : status.label,
      if (s.isLateAt(now)) 'Terlambat',
    ].join(', ');
  }
}

/// Tag "Berjalan · 12:40" dengan timer berjalan tiap detik.
class _RunningTag extends StatefulWidget {
  const _RunningTag({required this.startedAt, required this.now});
  final DateTime startedAt;
  final DateTime now;

  @override
  State<_RunningTag> createState() => _RunningTagState();
}

class _RunningTagState extends State<_RunningTag> {
  late DateTime _now = widget.now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = _now.add(const Duration(seconds: 1))),
    );
  }

  @override
  void didUpdateWidget(_RunningTag old) {
    super.didUpdateWidget(old);
    if (widget.now != old.now) _now = widget.now;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _now.difference(widget.startedAt);
    final text = d.isNegative ? '00:00' : _elapsed(d);
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(OlRadius.pill),
        ),
        child: Text(
          'Berjalan · $text',
          style: context.olText.caption.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  static String _elapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

class _LateBanner extends StatelessWidget {
  const _LateBanner({required this.minutes});
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.warnSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Terlambat $minutes mnt · tunggu, pindah jadwal, atau tandai tidak datang',
        style: context.olText.caption.copyWith(
          color: c.warn,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Tombol putih di kartu "now" (`.card.now .btn`).
class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: OlSize.buttonSmall + 4,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: context.ol.brandDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OlRadius.buttonSmall),
        ),
        textStyle: context.olText.button,
      ),
      child: Text(label),
    ),
  );
}
