import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/v1.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../features/owner/owner_widgets.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

/// PS-17 Notifikasi pasien (dibuka dari lonceng Beranda): kabar booking, pengingat jadwal, pembayaran,
/// paket, ringkasan sesi, dan program latihan. Ketuk → layar terkait. Pengaturan pengingat & promo di bawah.
class NotifikasiPasienPage extends ConsumerStatefulWidget {
  const NotifikasiPasienPage({super.key});

  @override
  ConsumerState<NotifikasiPasienPage> createState() => _NotifikasiPasienPageState();
}

class _NotifikasiPasienPageState extends ConsumerState<NotifikasiPasienPage> {
  PasienAppApi get _api => ref.read(pasienAppApiProvider);
  ({bool reminders, bool promo})? _prefs;

  final _items = <NotificationV>[];
  String? _cursor;
  bool _hasMore = false, _loading = true, _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _api.consent().then((p) {
      if (mounted) setState(() => _prefs = p);
    }).ignore();
    _load();
  }

  /// Muat dulu (titik "baru" tetap tampil di kunjungan ini), baru tandai semua sudah dibaca.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.notifications();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
      if (page.items.any((n) => n.unread)) {
        await _api.markAllRead().catchError((_) {});
        ref.invalidate(pasienUnreadProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _more() async {
    if (_loadingMore || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.notifications(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _save(({bool reminders, bool promo}) next) async {
    final before = _prefs;
    setState(() => _prefs = next);
    final ok = await runApi(
      context,
      () => _api.saveConsent(
        reminders: next.reminders,
        promo: next.promo,
        policyVersion: V1.policyVersion.isEmpty ? 'app' : V1.policyVersion,
      ).then((_) => true),
    );
    if (ok == null && mounted) setState(() => _prefs = before);
  }

  void _open(NotificationV n) => openPasienLink(GoRouter.of(context), n.deepLink);

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final fresh = [for (final n in _items) if (n.unread) n];
    final older = [for (final n in _items) if (!n.unread) n];
    final p = _prefs;
    return OlDetailScaffold(
      pinnedHeader: true,
      title: 'Notifikasi',
      children: [
        if (_loading && _items.isEmpty)
          const OlLoadingCard()
        else if (_error != null && _items.isEmpty)
          OlErrorCard(message: 'Notifikasi belum bisa dimuat.', onRetry: _load)
        else if (_items.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptyInbox,
              title: 'Belum ada notifikasi',
              message: 'Kabar booking, jadwal, pembayaran, dan latihan Anda akan muncul di sini.',
            ),
          )
        else ...[
          if (fresh.isNotEmpty) ...[
            const OlSectionHeader(title: 'Baru'),
            _Group([for (final n in fresh) _NotifRow(n, onTap: () => _open(n))]),
          ],
          if (older.isNotEmpty) ...[
            OlSectionHeader(title: fresh.isEmpty ? 'Terbaru' : 'Sebelumnya'),
            _Group([for (final n in older) _NotifRow(n, onTap: () => _open(n))]),
          ],
          if (_hasMore)
            OlButton.secondary(label: 'Muat lebih banyak', loading: _loadingMore, onPressed: _more),
          Text('Notifikasi lebih dari 90 hari dihapus otomatis.', style: t.caption.copyWith(color: c.muted)),
        ],
        if (p != null) ...[
          const OlSectionHeader(title: 'Pengaturan'),
          OlCard(
            child: Column(
              children: [
                OwToggleRow(
                  label: 'Pengingat jadwal & latihan',
                  subtitle: 'WhatsApp H-1 dan pengingat latihan harian',
                  value: p.reminders,
                  onChanged: (v) => _save((reminders: v, promo: p.promo)),
                ),
                OwToggleRow(
                  label: 'Info promo',
                  subtitle: 'Promo dan penawaran paket dari One Lotus',
                  value: p.promo,
                  onChanged: (v) => _save((reminders: p.reminders, promo: v)),
                ),
              ],
            ),
          ),
          Text(
            'Kabar pembayaran selalu dikirim dan tidak bisa dimatikan.',
            style: t.caption.copyWith(color: c.muted),
          ),
        ],
      ],
    );
  }
}

/// Ikon & warna per jenis notifikasi (sumber: backend `notify.PatientTypes`).
(OlIconData, Color, Color) _style(OlColors c, String type) => switch (type) {
  'payment.paid' || 'package.activated' => (OlIcons.checkCircle, c.ok, c.okSoft),
  'payment.failed' || 'payment.expired' || 'booking.rejected' => (OlIcons.alert, c.crit, c.critSoft),
  'booking.proposed' => (OlIcons.clock, c.warn, c.warnSoft),
  'booking.accepted' || 'session.reminder' => (OlIcons.calendar, c.brandDeep, c.brandSoft),
  'session.summary' => (OlIcons.report, c.brandDeep, c.brandSoft),
  'exercise.program' => (OlIcons.exercise, c.brandDeep, c.brandSoft),
  _ when type.startsWith('package') => (OlIcons.package, c.brandDeep, c.brandSoft),
  _ => (OlIcons.bell, c.brandDeep, c.brandSoft),
};

String _ago(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'Baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  if (d.inDays == 1) return 'Kemarin ${Fmt.time(at.toLocal())}';
  return '${Fmt.dayShort(at.toLocal())} ${Fmt.time(at.toLocal())}';
}

class _Group extends StatelessWidget {
  const _Group(this.rows);
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => OlCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: 66, color: context.ol.line),
          r,
        ],
      ],
    ),
  );
}

class _NotifRow extends StatelessWidget {
  const _NotifRow(this.n, {required this.onTap});
  final NotificationV n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final (icon, fg, bg) = _style(c, n.type);
    final linked = pasienRouteForLink(n.deepLink) != null;
    return InkWell(
      onTap: linked ? onTap : null,
      child: Container(
        color: n.unread ? c.brandSoft.withValues(alpha: .35) : null,
        padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: OlIcon(icon, size: 20, color: fg, weight: OlIconWeight.duotone),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n.title, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: OlSpace.sm),
                      Text(_ago(n.createdAt), style: t.caption.copyWith(color: c.faint)),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(n.body, style: t.caption.copyWith(color: c.muted), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (n.unread) ...[
              const SizedBox(width: OlSpace.sm),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: c.brand)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
