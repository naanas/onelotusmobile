import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

const _filters = {
  null: 'Semua',
  'invoice': 'Tagihan',
  'payment': 'Pembayaran',
  'refund': 'Refund',
  'export': 'Ekspor',
  'patient': 'Pasien',
};

/// OW-18 Audit log (baca-saja): siapa melakukan apa, kapan, dari perangkat apa.
class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  String? _action;
  final _items = <AuditLogV>[];
  String? _cursor;
  bool _more = true, _loading = false;
  Object? _error;

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
      final p = await ref.read(billingApiProvider).auditLogs(action: _action, cursor: _cursor);
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

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Audit log',
      children: [
        Wrap(
          spacing: OlSpace.sm,
          runSpacing: OlSpace.sm,
          children: [
            for (final MapEntry(:key, :value) in _filters.entries)
              OlChip(
                label: value,
                small: true,
                selected: _action == key,
                onTap: () {
                  _action = key;
                  _load(reset: true);
                },
              ),
          ],
        ),
        if (_error != null && _items.isEmpty)
          OlErrorCard(message: _error is AppError ? (_error as AppError).message : 'Audit log belum bisa dimuat.', onRetry: () => _load(reset: true))
        else if (_items.isEmpty && _loading)
          const OlLoadingCard()
        else if (_items.isEmpty)
          const OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada catatan', message: 'Setiap perubahan penting tercatat di sini.'))
        else
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (n, a) in _items.indexed)
                  OlListItem(
                    title: '${a.actorName.isEmpty ? 'Sistem' : a.actorName} · ${a.action}',
                    subtitle: [
                      '${Fmt.dayShort(a.at)} ${Fmt.time(a.at)}',
                      if (a.objectType.isNotEmpty) a.objectType,
                      if (a.deviceId != null) 'perangkat ${a.deviceId!.length > 8 ? a.deviceId!.substring(0, 8) : a.deviceId}',
                    ].join(' · '),
                    divider: n < _items.length - 1,
                  ),
              ],
            ),
          ),
        if (_more && _items.isNotEmpty) OlButton.text(label: 'Muat lagi', loading: _loading, onPressed: _load, expand: true),
        Text('Audit log hanya bisa dibaca, tidak bisa diubah atau dihapus.', style: t.caption.copyWith(color: c.muted)),
      ],
    );
  }
}
