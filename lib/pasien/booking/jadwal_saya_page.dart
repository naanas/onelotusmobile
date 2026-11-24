import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';
import '../pasien_session.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/common/billing_common.dart';
import 'booking_request_card.dart';

/// PS-10 Jadwal saya: booking mendatang & riwayat sesi. Ubah/batal → PS-11 (batas waktu dari server, TODO(workshop) §16 no. 8).
class JadwalSayaPage extends ConsumerStatefulWidget {
  const JadwalSayaPage({super.key});

  @override
  ConsumerState<JadwalSayaPage> createState() => _JadwalSayaPageState();
}

class _JadwalSayaPageState extends ConsumerState<JadwalSayaPage> {
  bool _history = false;
  int _gen = 0;
  String? _accepting;

  PasienAppApi get _app => ref.read(pasienAppApiProvider);

  Future<void> _change(String bookingId) async {
    await context.push('${PRoutes.ubahJadwal}?id=$bookingId');
    if (mounted) setState(() => _gen++);
  }

  /// Setujui jam usulan klinik → langsung terkonfirmasi (tidak perlu menunggu klinik lagi).
  Future<void> _accept(BookingRequestV r) async {
    setState(() => _accepting = r.id);
    final ok = await runApi(context, () => _app.acceptProposal(r.id).then((_) => true));
    if (!mounted) return;
    setState(() {
      _accepting = null;
      if (ok == true) _gen++;
    });
    if (ok == true) {
      context.feedback.success(
        'Jadwal ${Fmt.dayShort(r.proposedStart!.toLocal())} ${Fmt.time(r.proposedStart!.toLocal())} terkonfirmasi.',
      );
    }
  }

  String _relative(DateTime at) {
    final days = DateUtils.dateOnly(
      at,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    return switch (days) {
      0 => 'Hari ini',
      1 => 'Besok',
      < 0 => '',
      _ => '$days hari lagi',
    };
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    pinnedHeader: true,
    title: 'Jadwal saya',
    children: [
      OlSegmented<bool>(
        segments: const {false: 'Mendatang', true: 'Riwayat'},
        value: _history,
        onChanged: (v) => setState(() => _history = v),
      ),
      // Permintaan yang belum jadi sesi: menunggu konfirmasi, usulan jam dari klinik, atau ditolak.
      if (!_history)
        OlAsync<List<BookingRequestV>>(
          key: ValueKey(('req', _gen)),
          load: _app.bookingRequests,
          builder: (context, list, _) => [
            if (list.isNotEmpty) const OlSectionHeader(title: 'Permintaan booking'),
            for (final r in list)
              BookingRequestCard(
                request: r,
                busy: _accepting == r.id,
                onAccept: () => _accept(r),
                onChange: () => _change(r.id),
                onRebook: () => context.go(PRoutes.booking),
              ),
            if (list.isNotEmpty) const OlSectionHeader(title: 'Jadwal terkonfirmasi'),
          ],
        ),
      OlAsync<List<PasienSessionItem>>(
        key: ValueKey((_history, _gen)),
        load: () => ref.read(pasienApiProvider).sessions(past: _history),
        builder: (context, list, _) {
          final c = context.ol;
          final t = context.olText;
          if (list.isEmpty) {
            return [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptySchedule,
                  title: _history ? 'Belum ada riwayat' : 'Belum ada jadwal',
                  message: _history
                      ? 'Sesi yang sudah lewat muncul di sini.'
                      : 'Buat jadwal terapi di tab Booking.',
                ),
              ),
            ];
          }
          return [
            for (final s in list)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        OlTag(
                          s.status.label,
                          tone: switch (s.status) {
                            SessionStatus.awaitingConfirmation =>
                              OlTagTone.warn,
                            SessionStatus.noShow ||
                            SessionStatus.cancelled => OlTagTone.crit,
                            SessionStatus.paid ||
                            SessionStatus.done => OlTagTone.ok,
                            _ => OlTagTone.outline,
                          },
                        ),
                        const Spacer(),
                        Text(
                          _relative(s.startAt),
                          style: t.body.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        text: '${Fmt.date(s.startAt)} · ',
                        children: [
                          TextSpan(
                            text: Fmt.time(s.startAt),
                            style: t.mono.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      style: t.heading.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.serviceName} · ${s.durationMin} mnt · ${s.therapistName}',
                      style: t.body.copyWith(fontSize: 14.5, color: c.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.homeVisit != null
                          ? 'Home visit · ${s.homeVisit!.address}'
                          : [
                              s.branchName,
                              if (s.branchAddress.isNotEmpty) s.branchAddress,
                            ].join(' · '),
                      style: t.body.copyWith(fontSize: 14.5),
                    ),
                    if (!_history && s.status != SessionStatus.cancelled) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OlButton.text(
                          label: 'Ubah / batalkan',
                          small: true,
                          onPressed: () => _change(s.id),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ];
        },
      ),
    ],
  );
}
