import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'klinik_api.dart';

/// Badge lonceng staf. Dimuat ulang saat header tampil lagi, aplikasi dibuka kembali, ada push masuk,
/// dan tiap 2 menit selama terlihat.
final staffUnreadProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(klinikApiProvider).belumDibaca());

/// Rute dari deep link notifikasi staf (`onelotus://klinik/formulir/<id>`). Null = tidak bisa dibuka.
String? staffRouteForLink(String? link) {
  final uri = link == null ? null : Uri.tryParse(link);
  if (uri == null || uri.scheme != 'onelotus' || uri.host != 'klinik') return null;
  return switch (uri.pathSegments) {
    ['formulir', final id] => Routes.klinikFormulirDetail(id),
    ['formulir'] => Routes.klinikFormulir,
    ['pasien', final id] => Routes.klinikDetail(id),
    _ => null,
  };
}

/// Lonceng di kanan atas header Data Pasien (posisi sama dengan lonceng Beranda pasien).
class StaffNotifBell extends ConsumerStatefulWidget {
  const StaffNotifBell({super.key, this.onHero = true});
  final bool onHero;

  @override
  ConsumerState<StaffNotifBell> createState() => _StaffNotifBellState();
}

class _StaffNotifBellState extends ConsumerState<StaffNotifBell> {
  late final AppLifecycleListener _life;
  Timer? _tick;
  bool _visible = true;
  int _last = 0;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _refresh);
    _tick = Timer.periodic(const Duration(minutes: 2), (_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible && !_visible) WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _visible = visible;
  }

  void _refresh() {
    if (mounted && _visible) ref.invalidate(staffUnreadProvider);
  }

  @override
  void dispose() {
    _life.dispose();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    await context.push(Routes.klinikNotifikasi);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final n = ref.watch(staffUnreadProvider).whenOrNull(data: (v) => v);
    if (n != null) _last = n;
    return OlIconButton(
      icon: OlIcons.bell,
      semanticLabel: 'Notifikasi',
      onHero: widget.onHero,
      badge: _last,
      onPressed: _open,
    );
  }
}

/// Notifikasi staf: pasien baru booking (form web / aplikasi). Ketuk → kiriman di Formulir.
class StaffNotifikasiPage extends ConsumerStatefulWidget {
  const StaffNotifikasiPage({super.key});

  @override
  ConsumerState<StaffNotifikasiPage> createState() => _StaffNotifikasiPageState();
}

class _StaffNotifikasiPageState extends ConsumerState<StaffNotifikasiPage> {
  KlinikApi get _api => ref.read(klinikApiProvider);
  final _items = <NotificationV>[];
  String? _cursor;
  bool _hasMore = false, _loading = true, _loadingMore = false;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Muat dulu (titik "baru" tetap tampil di kunjungan ini), baru tandai semua sudah dibaca.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.notifikasi();
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
        await _api.bacaSemua().catchError((_) {});
        ref.invalidate(staffUnreadProvider);
      }
    } on AppError catch (e) {
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
      final page = await _api.notifikasi(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _open(NotificationV n) {
    final r = staffRouteForLink(n.deepLink);
    if (r != null) context.push(r);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final fresh = [for (final n in _items) if (n.unread) n];
    final older = [for (final n in _items) if (!n.unread) n];
    return OlDetailScaffold(
      title: 'Notifikasi',
      onRefresh: _load,
      children: [
        if (_loading && _items.isEmpty)
          const OlLoadingCard()
        else if (_error != null && _items.isEmpty)
          OlErrorCard(message: _error!.message, onRetry: _load)
        else if (_items.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptyInbox,
              title: 'Belum ada notifikasi',
              message: 'Kabar pasien baru booking dari form web dan aplikasi akan muncul di sini.',
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
          if (_hasMore) OlButton.secondary(label: 'Muat lebih banyak', loading: _loadingMore, onPressed: _more),
          Text('Notifikasi lebih dari 90 hari dihapus otomatis.', style: t.caption.copyWith(color: c.muted)),
        ],
      ],
    );
  }
}

(OlIconData, Color, Color) _style(OlColors c, String type) => switch (type) {
  'booking.new' => (OlIcons.calendar, c.brandDeep, c.brandSoft),
  'payment.paid' => (OlIcons.checkCircle, c.ok, c.okSoft),
  'payment.failed' => (OlIcons.alert, c.crit, c.critSoft),
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
    final linked = staffRouteForLink(n.deepLink) != null;
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
