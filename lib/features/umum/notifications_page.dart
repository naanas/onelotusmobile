import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-09 Pusat notifikasi: Semua / Belum dibaca, tandai semua dibaca, ketuk → layar terkait.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _unread = false;
  final _items = <NotificationV>[];
  String? _cursor;
  bool _more = true, _loading = false;
  Object? _error;

  BillingApi get _api => ref.read(billingApiProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _items.clear();
      _cursor = null;
      _more = true;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _api.notifications(unreadOnly: _unread, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(p.items);
        _cursor = p.nextCursor;
        _more = p.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _readAll() async {
    try {
      await _api.markAllRead();
      if (mounted) _load(reset: true);
    } catch (_) {
      if (mounted) context.feedback.info('Belum bisa menandai. Coba lagi.');
    }
  }

  Future<void> _open(NotificationV n) async {
    if (n.unread) {
      _api.markRead(n.id).ignore();
      setState(() {
        final i = _items.indexOf(n);
        if (i >= 0) {
          _items[i] = NotificationV(
            id: n.id,
            type: n.type,
            title: n.title,
            body: n.body,
            createdAt: n.createdAt,
            deepLink: n.deepLink,
            readAt: DateTime.now(),
          );
        }
      });
    }
    final route = _route(n.deepLink, ref.read(authProvider).activeRole);
    if (route != null) await context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Notifikasi',
      onRefresh: () => _load(reset: true),
      actions: [
        OlIconButton(
          icon: OlIcons.check,
          semanticLabel: 'Tandai semua dibaca',
          onPressed: _readAll,
        ),
      ],
      children: [
        OlSegmented<bool>(
          segments: const {false: 'Semua', true: 'Belum dibaca'},
          value: _unread,
          onChanged: (v) {
            _unread = v;
            _load(reset: true);
          },
        ),
        if (_error != null && _items.isEmpty)
          OlErrorCard(
            message: _error is AppError
                ? (_error as AppError).message
                : 'Notifikasi belum bisa dimuat.',
            onRetry: () => _load(reset: true),
          )
        else if (_items.isEmpty && _loading)
          const OlLoadingCard()
        else if (_items.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptyInbox,
              title: 'Tidak ada notifikasi',
              message: 'Kabar penting untukmu muncul di sini.',
            ),
          )
        else
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, n) in _items.indexed)
                  OlListItem(
                    leading: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: n.unread ? c.brand : Colors.transparent,
                      ),
                    ),
                    title: n.title,
                    subtitle: [
                      if (n.body.isNotEmpty) n.body,
                      '${Fmt.dayShort(n.createdAt)} ${Fmt.time(n.createdAt)}',
                    ].join(' · '),
                    divider: i < _items.length - 1,
                    onTap: () => _open(n),
                  ),
              ],
            ),
          ),
        if (_more && _items.isNotEmpty)
          OlButton.text(
            label: 'Muat lagi',
            loading: _loading,
            onPressed: _load,
            expand: true,
          ),
        if (_items.isNotEmpty)
          Text(
            'Notifikasi lebih dari 90 hari dihapus otomatis.',
            style: t.caption.copyWith(color: c.muted),
          ),
      ],
    );
  }
}

/// `onelotus://<jenis>/<id>` → rute aplikasi sesuai peran aktif; null bila tidak ada layar tujuan.
String? _route(String? link, Role? role) {
  if (link == null || !link.startsWith('onelotus://')) return null;
  final uri = Uri.parse(link);
  final kind = uri.host;
  final id = uri.pathSegments.firstOrNull;
  return switch ((kind, role)) {
    ('approvals', Role.owner) => Routes.ownerPersetujuan,
    ('cash-closings', Role.owner) => Routes.ownerLaporan,
    ('receivables', Role.kasir) => Routes.kasirPiutang,
    ('cash-handovers', Role.kasir) => Routes.kasirTerimaKas,
    ('cash-handovers', Role.terapis) => Routes.terapisKas,
    ('invoices', Role.kasir) when id != null => Routes.kasirTagihan(id),
    ('transfers', Role.kasir) => Routes.kasirVerifikasiTransfer,
    ('sessions', Role.terapis) when id != null => Routes.terapisSesi(id),
    ('patients', Role.terapis) when id != null => Routes.terapisPasienDetail(
      id,
    ),
    ('patients', Role.kasir) when id != null => Routes.kasirPasienDetail(id),
    ('commissions', Role.terapis) => Routes.terapisKomisi,
    _ => null,
  };
}
