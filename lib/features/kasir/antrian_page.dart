import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import '../../data/sync/sync_providers.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../shell/role_shell.dart';
import '../umum/sync_details.dart';
import 'demo_data.dart';

/// KS-01 Antrian hari ini (tab Antrian kasir): tandai hadir, ganti terapis/ruang,
/// lengkapi data pasien baru, tagih sesi selesai, walk-in.
class AntrianPage extends ConsumerStatefulWidget {
  const AntrianPage({super.key});

  @override
  ConsumerState<AntrianPage> createState() => _AntrianPageState();
}

class _AntrianPageState extends ConsumerState<AntrianPage> {
  final _items = demoQueue();

  Future<void> _changeTherapist(DemoQueueItem it) async {
    final pick = await context.feedback.sheet<String>(
      title: 'Ganti terapis / ruang',
      message: '${it.name} · ${it.time}',
      actions: [
        for (final t in const [
          'Dimas · ruang 2',
          'Laras · ruang 1',
          'Fajar · ruang 3',
        ])
          SheetAction(
            t,
            t,
            variant: t.startsWith(it.therapist)
                ? OlButtonVariant.primary
                : OlButtonVariant.secondary,
          ),
      ],
    );
    if (pick == null || !mounted) return;
    final [th, room] = pick.split(' · ');
    setState(() {
      it.therapist = th;
      it.room = room;
    });
    context.feedback.success('Dipindah ke $th, $room. Terapis diberi tahu.');
  }

  void _markArrived(DemoQueueItem it) {
    HapticFeedback.lightImpact();
    setState(() {
      it.state = QueueState.arrived;
      it.arrivedAt = TimeOfDay.now().format(context).replaceAll(':', '.');
    });
    context.feedback.success('${it.name} ditandai hadir. Terapis diberi tahu.');
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncStatusProvider);
    final now = ref.watch(clockProvider)();
    final header = OlAppHeader(
      hero: true,
      title: 'Antrian',
      context_: headerContext(ref, now),
      actions: [
        OlIconButton(
          icon: OlIcons.search,
          semanticLabel: 'Cari',
          onHero: true,
          onPressed: () => context.push(Routes.search),
        ),
        const SizedBox(width: 4),
        OlIconButton(
          icon: OlIcons.bell,
          semanticLabel: 'Notifikasi',
          badge: 2,
          onHero: true,
          onPressed: () => context.push(Routes.notifications),
        ),
      ],
      below: SyncIndicator(
        status: sync,
        onHero: true,
        onTap: () => openSyncDetails(context, sync),
      ),
    );

    // Urutan kolom status (§5.11): berjalan → hadir → dijadwalkan → selesai/belum bayar.
    int order(QueueState s) => switch (s) {
      QueueState.running => 0,
      QueueState.arrived => 1,
      QueueState.scheduled => 2,
      QueueState.unpaid => 3,
      QueueState.paid => 4,
    };
    final sorted = [..._items]
      ..sort((a, b) => order(a.state).compareTo(order(b.state)));

    return OlPageBody(
      heroOverlap: true,
      header: header,
      children: [
        const FeedbackBannerHost(),
        for (final it in sorted)
          _QueueCard(
            item: it,
            onChangeTherapist: () => _changeTherapist(it),
            onMarkArrived: () => _markArrived(it),
            onCompleteData: () => context.push(Routes.kasirPasienForm),
            onBill: () => context.go(Routes.kasirKasir),
          ),
        OlButton.secondary(
          label: '+ Sesi tanpa jadwal (walk-in)',
          onPressed: () => context.push(Routes.kasirBuatJadwal),
        ),
        OlButton.text(
          label: 'Booking masuk · 3 menunggu',
          expand: true,
          onPressed: () => context.push(Routes.kasirBooking),
        ),
      ],
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.item,
    required this.onChangeTherapist,
    required this.onMarkArrived,
    required this.onCompleteData,
    required this.onBill,
  });

  final DemoQueueItem item;
  final VoidCallback onChangeTherapist;
  final VoidCallback onMarkArrived;
  final VoidCallback onCompleteData;
  final VoidCallback onBill;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final it = item;
    final tag = switch (it.state) {
      QueueState.running => const OlTag('Berjalan', tone: OlTagTone.fill),
      QueueState.arrived => OlTag('Hadir ${it.arrivedAt ?? ''}'.trim()),
      QueueState.scheduled => const OlTag('Dijadwalkan', tone: OlTagTone.muted),
      QueueState.unpaid => const OlTag('Belum bayar', tone: OlTagTone.warn),
      QueueState.paid => const OlTag('Lunas', tone: OlTagTone.ok),
    };
    final caption = switch (it.state) {
      QueueState.unpaid => 'Selesai ${it.finishedAt} · siap ditagih',
      _ => [it.service, it.therapist, ?it.room].join(' · '),
    };
    return OlCard(
      onTap: it.state == QueueState.unpaid ? onBill : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                it.time,
                style: t.mono.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (it.newPatient)
                      const OlTag('Pasien baru', tone: OlTagTone.outline),
                    tag,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(it.name, style: t.heading),
          Text(caption, style: t.body.copyWith(color: c.muted)),
          if (it.state == QueueState.arrived) ...[
            const SizedBox(height: 10),
            OlButton.secondary(
              label: 'Ganti terapis / ruang',
              small: true,
              onPressed: onChangeTherapist,
            ),
          ],
          if (it.state == QueueState.scheduled) ...[
            if (it.dataIncomplete) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: c.warnSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Lengkapi data pasien sebelum tandai hadir',
                  style: t.caption.copyWith(
                    fontSize: 13,
                    color: c.warn,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            OlFootRow(
              children: [
                if (it.dataIncomplete)
                  OlButton.secondary(
                    label: 'Lengkapi data',
                    small: true,
                    onPressed: onCompleteData,
                  ),
                OlButton(
                  label: 'Tandai hadir',
                  small: true,
                  onPressed: it.dataIncomplete ? null : onMarkArrived,
                ),
              ],
            ),
          ],
          if (it.state == QueueState.unpaid) ...[
            const SizedBox(height: 10),
            OlButton(
              label: 'Tagih',
              small: true,
              icon: OlIcons.receipt,
              onPressed: onBill,
            ),
          ],
        ],
      ),
    );
  }
}
