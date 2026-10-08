import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

class _Notif {
  _Notif(
    this.icon,
    this.tone,
    this.title,
    this.body,
    this.time, {
    this.unread = false,
    this.route,
  });
  final OlIconData icon;
  final OlTagTone tone;
  final String title;
  final String body;
  final String time;
  bool unread;

  /// Deep link ke layar terkait (A.0).
  final String? route;
}

/// UM-09 Pusat notifikasi: Semua / Belum dibaca, tandai semua dibaca, ketuk → layar terkait.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _tab = 'all';
  final _today = [
    _Notif(
      OlIcons.calendar,
      OlTagTone.brand,
      'Pasien hadir: Andi Pratama',
      'Adjustment Therapy · ruang 2 · 10.30',
      '5 mnt',
      unread: true,
      route: '/terapis/rekam/s2',
    ),
    _Notif(
      OlIcons.sync,
      OlTagTone.warn,
      'Sesi dipindah oleh kasir',
      'Sari Wulandari → 15.30 (sebelumnya 15.00)',
      '32 mnt',
      unread: true,
      route: '/terapis/jadwal',
    ),
    _Notif(
      OlIcons.exercise,
      OlTagTone.ok,
      'Rina membalas program latihan',
      '"Calf raise terasa ringan sekarang"',
      '08.15',
      unread: true,
      route: '/terapis/pasien/p0387',
    ),
  ];
  final _yesterday = [
    _Notif(
      OlIcons.percent,
      OlTagTone.muted,
      'Komisi September disetujui',
      'Siap dibayar oleh owner',
      'Sen',
      route: '/terapis/komisi',
    ),
    _Notif(
      OlIcons.checkCircle,
      OlTagTone.muted,
      'Cuti 14–15 Okt disetujui',
      '3 sesi dipindah ke Fajar',
      'Sen',
      route: '/terapis/jadwal-minggu',
    ),
  ];

  int get _unread => [..._today, ..._yesterday].where((n) => n.unread).length;

  @override
  Widget build(BuildContext context) {
    final unreadOnly = _tab == 'unread';
    final groups = [
      ('Hari ini', _today.where((n) => !unreadOnly || n.unread).toList()),
      ('Kemarin', _yesterday.where((n) => !unreadOnly || n.unread).toList()),
    ].where((g) => g.$2.isNotEmpty).toList();

    return OlDetailScaffold(
      title: 'Notifikasi',
      actions: [
        TextButton(
          onPressed: _unread == 0
              ? null
              : () {
                  setState(() {
                    for (final n in [..._today, ..._yesterday]) {
                      n.unread = false;
                    }
                  });
                  context.feedback.success('Semua notifikasi ditandai dibaca.');
                },
          style: TextButton.styleFrom(
            foregroundColor: context.ol.brand,
            textStyle: context.olText.button,
          ),
          child: const Text('Tandai semua dibaca'),
        ),
      ],
      children: [
        OlSegmented<String>(
          segments: {'all': 'Semua', 'unread': 'Belum dibaca ($_unread)'},
          value: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
        if (groups.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptyInbox,
              title: 'Semua sudah dibaca',
              message: 'Notifikasi baru akan muncul di sini.',
            ),
          ),
        for (final (label, items) in groups) ...[
          OlOverline(label),
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, n) in items.indexed)
                  _NotifItem(
                    n: n,
                    divider: i < items.length - 1,
                    onTap: () {
                      setState(() => n.unread = false);
                      if (n.route != null) context.push(n.route!);
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// NotificationItem (§4): ikon jenis, judul, waktu relatif, titik belum dibaca.
class _NotifItem extends StatelessWidget {
  const _NotifItem({
    required this.n,
    required this.divider,
    required this.onTap,
  });

  final _Notif n;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final (Color bg, Color fg) = switch (n.tone) {
      OlTagTone.brand => (c.brandSoft, c.brand),
      OlTagTone.warn => (c.warnSoft, c.warn),
      OlTagTone.ok => (c.okSoft, c.ok),
      _ => (c.surfaceAlt, c.muted),
    };
    return Semantics(
      container: true,
      button: true,
      label:
          '${n.unread ? 'Belum dibaca. ' : ''}${n.title}. ${n.body}. ${n.time}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: OlIcon(
                    n.icon,
                    color: fg,
                    weight: OlIconWeight.duotone,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: t.bodyStrong.copyWith(
                        fontSize: 15,
                        fontWeight: n.unread
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    Text(n.body, style: t.body.copyWith(color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(n.time, style: t.body.copyWith(color: c.muted)),
                  if (n.unread) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: c.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
