import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../data/sync/sync_providers.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../shell/role_shell.dart';
import '../umum/sync_details.dart';

typedef _Queue = ({List<Session> today, int bookings});

/// KS-01 Antrian hari ini (tab Antrian kasir): jadwal cabang hari ini dari `GET /v1/sessions`.
/// Tandai hadir, ganti terapis/ruang, tidak datang / batal (alasan wajib), walk-in, booking masuk.
class AntrianPage extends ConsumerStatefulWidget {
  const AntrianPage({super.key});

  @override
  ConsumerState<AntrianPage> createState() => _AntrianPageState();
}

class _AntrianPageState extends ConsumerState<AntrianPage> {
  int _gen = 0;

  OneLotusApi get _api => ref.read(oneLotusApiProvider);
  Branch? get _branch => ref.read(authProvider).activeBranch;

  Future<_Queue> _load() async {
    final branch = _branch;
    if (branch == null) return (today: <Session>[], bookings: 0);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final r = await (
      _api.sessions(
        branchId: branch.id,
        from: day,
        to: day.add(const Duration(days: 1)),
      ),
      _api.sessions(
        branchId: branch.id,
        from: day,
        to: day.add(const Duration(days: 31)),
      ),
    ).wait;
    return (
      today: [
        for (final s in r.$1)
          if (s.status != SessionStatus.awaitingConfirmation &&
              s.status != SessionStatus.cancelled)
            s,
      ],
      bookings: r.$2
          .where((s) => s.status == SessionStatus.awaitingConfirmation)
          .length,
    );
  }

  void _reload() => setState(() => _gen++);

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      context.feedback.success(success);
      _reload();
    } on AppError catch (e) {
      if (!mounted) return;
      final msg = e.fieldErrors.values.expand((v) => v).firstOrNull;
      if (msg != null) {
        context.feedback.info(msg);
      } else {
        context.feedback.error(e);
      }
    }
  }

  Future<void> _markArrived(Session s) {
    HapticFeedback.lightImpact();
    return _run(
      () => _api.setStatus(s.id, SessionStatus.arrived),
      '${s.patientName} ditandai hadir.',
    );
  }

  Future<void> _changeTherapist(Session s) async {
    final branch = _branch;
    if (branch == null) return;
    final List<Therapist> therapists;
    final List<Room> rooms;
    try {
      therapists = await _api.therapists(branch.id, date: s.startAt);
      rooms = await _api.rooms(branch.id);
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
      return;
    }
    if (!mounted) return;
    final pick = await context.feedback.sheet<String>(
      title: 'Ganti terapis',
      message: '${s.patientName} · ${Fmt.time(s.startAt)}',
      actions: [
        for (final t in therapists)
          if (t.available != false)
            SheetAction(
              t.name,
              t.id,
              variant: t.id == s.therapistId
                  ? OlButtonVariant.primary
                  : OlButtonVariant.secondary,
            ),
      ],
    );
    if (pick == null || !mounted) return;
    String? room = s.room;
    if (rooms.isNotEmpty && !s.isHomeVisit) {
      room = await context.feedback.sheet<String>(
        title: 'Pilih ruang',
        actions: [
          for (final r in rooms)
            SheetAction(
              r.name,
              r.name,
              variant: r.name == s.room
                  ? OlButtonVariant.primary
                  : OlButtonVariant.secondary,
            ),
        ],
      );
      if (room == null || !mounted) return;
    }
    final name = therapists.firstWhere((t) => t.id == pick).name;
    await _run(
      () => _api.updateSession(s.id, therapistId: pick, room: room),
      'Dipindah ke $name${room == null ? '' : ', $room'}.',
    );
  }

  Future<void> _more(Session s) async {
    final action = await context.feedback.sheet<String>(
      title: s.patientName,
      message: '${Fmt.time(s.startAt)} · ${s.serviceName}',
      actions: const [
        SheetAction(
          'Tidak datang',
          'no_show',
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Batalkan sesi',
          'cancel',
          variant: OlButtonVariant.secondary,
        ),
      ],
    );
    if (action == null || !mounted) return;
    final noShow = action == 'no_show';
    final res = await context.feedback.choose(
      ConfirmSpec(
        title: noShow ? 'Tandai tidak datang?' : 'Batalkan sesi ini?',
        message:
            '${s.patientName} · ${Fmt.time(s.startAt)}. Tercatat di riwayat & audit log.',
        confirmLabel: noShow ? 'Tidak datang' : 'Batalkan sesi',
        reasonLabel: 'Alasan',
      ),
    );
    if (!res.confirmed || !mounted) return;
    await _run(
      () => _api.setStatus(
        s.id,
        noShow ? SessionStatus.noShow : SessionStatus.cancelled,
        reason: res.reason,
      ),
      noShow ? 'Ditandai tidak datang.' : 'Sesi dibatalkan.',
    );
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
          icon: OlIcons.refresh,
          semanticLabel: 'Muat ulang',
          onHero: true,
          onPressed: _reload,
        ),
      ],
      below: SyncIndicator(
        status: sync,
        onHero: true,
        onTap: () => openSyncDetails(context, sync),
      ),
    );

    // Urutan (§5.11): berjalan → hadir → dijadwalkan → selesai/belum bayar → lunas → tidak datang.
    int order(SessionStatus s) => switch (s) {
      SessionStatus.running => 0,
      SessionStatus.arrived => 1,
      SessionStatus.scheduled => 2,
      SessionStatus.done || SessionStatus.unpaid => 3,
      SessionStatus.paid => 4,
      _ => 5,
    };

    return OlPageBody(
      heroOverlap: true,
      header: header,
      children: [
        const FeedbackBannerHost(),
        OlAsync<_Queue>(
          key: ValueKey(_gen),
          load: _load,
          builder: (context, q, _) {
            final sorted = [...q.today]
              ..sort((a, b) {
                final o = order(a.status).compareTo(order(b.status));
                return o != 0 ? o : a.startAt.compareTo(b.startAt);
              });
            return [
              if (sorted.isEmpty)
                const OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptySchedule,
                    title: 'Belum ada antrian hari ini',
                    message:
                        'Buat jadwal atau tambah sesi tanpa jadwal (walk-in).',
                  ),
                ),
              for (final s in sorted)
                _QueueCard(
                  session: s,
                  now: now,
                  onChangeTherapist: () => _changeTherapist(s),
                  onMarkArrived: () => _markArrived(s),
                  onMore: () => _more(s),
                ),
              OlButton.secondary(
                label: '+ Sesi tanpa jadwal (walk-in)',
                onPressed: () async {
                  await context.push('${Routes.kasirBuatJadwal}?walkin=1');
                  _reload();
                },
              ),
              OlButton.text(
                label: q.bookings > 0
                    ? 'Booking masuk · ${q.bookings} menunggu'
                    : 'Booking masuk',
                expand: true,
                onPressed: () async {
                  await context.push(Routes.kasirBooking);
                  _reload();
                },
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.session,
    required this.now,
    required this.onChangeTherapist,
    required this.onMarkArrived,
    required this.onMore,
  });

  final Session session;
  final DateTime now;
  final VoidCallback onChangeTherapist;
  final VoidCallback onMarkArrived;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final s = session;
    final tag = switch (s.status) {
      SessionStatus.running => const OlTag('Berjalan', tone: OlTagTone.fill),
      SessionStatus.arrived => OlTag(
        'Hadir ${s.arrivedAt == null ? '' : Fmt.time(s.arrivedAt!)}'.trim(),
      ),
      SessionStatus.scheduled =>
        s.isLateAt(now)
            ? const OlTag('Terlambat', tone: OlTagTone.warn)
            : const OlTag('Dijadwalkan', tone: OlTagTone.muted),
      SessionStatus.done || SessionStatus.unpaid => const OlTag(
        'Selesai · belum bayar',
        tone: OlTagTone.warn,
      ),
      SessionStatus.paid => const OlTag('Lunas', tone: OlTagTone.ok),
      SessionStatus.noShow => const OlTag('Tidak datang', tone: OlTagTone.crit),
      _ => OlTag(s.status.label, tone: OlTagTone.muted),
    };
    final caption = [
      s.serviceName,
      s.therapistName,
      if (s.isHomeVisit) 'home visit' else ?s.room,
    ].join(' · ');
    final active =
        s.status == SessionStatus.scheduled ||
        s.status == SessionStatus.arrived;
    return OlCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (s.isNewPatient)
                      const OlTag('Pasien baru', tone: OlTagTone.outline),
                    if (s.needsAction)
                      const OlTag('Perlu tindakan', tone: OlTagTone.crit),
                    tag,
                  ],
                ),
              ),
              if (active)
                OlIconButton(
                  icon: OlIcons.more,
                  semanticLabel: 'Aksi lain',
                  onPressed: onMore,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.patientName, style: t.heading),
          Text(caption, style: t.body.copyWith(color: c.muted)),
          if (s.status == SessionStatus.arrived) ...[
            const SizedBox(height: 10),
            OlButton.secondary(
              label: 'Ganti terapis / ruang',
              small: true,
              onPressed: onChangeTherapist,
            ),
          ],
          if (s.status == SessionStatus.scheduled) ...[
            const SizedBox(height: 10),
            OlFootRow(
              children: [
                OlButton.secondary(
                  label: 'Ganti terapis',
                  small: true,
                  onPressed: onChangeTherapist,
                ),
                OlButton(
                  label: 'Tandai hadir',
                  small: true,
                  onPressed: onMarkArrived,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
