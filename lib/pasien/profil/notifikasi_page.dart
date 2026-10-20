import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/api_client.dart';
import '../../data/api/v1.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../features/owner/owner_widgets.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// PS-17 Notifikasi pasien + pengaturan: pengingat jadwal/latihan dan promo (persetujuan §10).
class NotifikasiPasienPage extends ConsumerStatefulWidget {
  const NotifikasiPasienPage({super.key});

  @override
  ConsumerState<NotifikasiPasienPage> createState() => _NotifikasiPasienPageState();
}

class _NotifikasiPasienPageState extends ConsumerState<NotifikasiPasienPage> {
  PasienAppApi get _api => ref.read(pasienAppApiProvider);
  ({bool reminders, bool promo})? _prefs;

  @override
  void initState() {
    super.initState();
    _api.consent().then((p) {
      if (mounted) setState(() => _prefs = p);
    }).ignore();
    _api.markAllRead().ignore();
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

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    return OlDetailScaffold(
      title: 'Notifikasi',
      children: [
        if (p != null)
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
        OlAsync<CursorPage<NotificationV>>(
          load: _api.notifications,
          builder: (context, page, _) {
            final c = context.ol;
            final t = context.olText;
            final list = page.items;
            if (list.isEmpty) {
              return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada notifikasi', message: 'Kabar jadwal, latihan, dan pembayaran muncul di sini.'))];
            }
            return [
              OlCard(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                child: Column(
                  children: [
                    for (final (i, n) in list.indexed)
                      OlListItem(
                        title: n.title,
                        subtitle: [if (n.body.isNotEmpty) n.body, '${Fmt.dayShort(n.createdAt)} ${Fmt.time(n.createdAt)}'].join(' · '),
                        trailing: n.unread ? Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: c.brand)) : null,
                        divider: i < list.length - 1,
                      ),
                  ],
                ),
              ),
              Text('Notifikasi lebih dari 90 hari dihapus otomatis.', style: t.caption.copyWith(color: c.muted)),
            ];
          },
        ),
      ],
    );
  }
}
