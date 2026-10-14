import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../shared/slot_sheet.dart';

/// KS-07 Booking masuk: sesi berstatus Menunggu konfirmasi (31 hari ke depan).
/// Terima (server memeriksa bentrok) · Usulkan jam lain (slot server) · Tolak (alasan wajib).
class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key});

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  int _gen = 0;

  OneLotusApi get _api => ref.read(oneLotusApiProvider);

  Future<List<Session>> _load() async {
    final branch = ref.read(authProvider).activeBranch!;
    final day = DateUtils.dateOnly(DateTime.now());
    final list = await _api.sessions(
      branchId: branch.id,
      from: day,
      to: day.add(const Duration(days: 31)),
    );
    return [
      for (final s in list)
        if (s.status == SessionStatus.awaitingConfirmation) s,
    ];
  }

  void _reload() => setState(() => _gen++);

  Future<void> _run(Future<void> Function() f, String ok) async {
    try {
      await f();
      if (!mounted) return;
      context.feedback.success(ok);
      _reload();
    } on AppError catch (e) {
      if (!mounted) return;
      final msg = e.fieldErrors.values.expand((v) => v).firstOrNull;
      msg != null ? context.feedback.info(msg) : context.feedback.error(e);
    }
  }

  Future<void> _accept(Session s) => _run(
    () => _api.setStatus(s.id, SessionStatus.scheduled),
    'Booking ${s.patientName} diterima.',
  );

  Future<void> _reject(Session s) async {
    final r = await context.feedback.choose(
      ConfirmSpec(
        title: 'Tolak booking ${s.patientName}?',
        message: 'Booking dibatalkan dan alasannya tercatat.',
        confirmLabel: 'Tolak booking',
        reasonLabel: 'Alasan',
      ),
    );
    if (!r.confirmed) return;
    await _run(
      () => _api.setStatus(s.id, SessionStatus.cancelled, reason: r.reason),
      'Booking ditolak.',
    );
  }

  Future<void> _propose(Session s) async {
    final slot = await pickSlot(
      context,
      title: 'Usulkan jam lain',
      branchId: s.branchId,
      serviceId: s.serviceId,
      excludeSessionId: s.id,
    );
    if (slot == null || !mounted) return;
    await _run(() async {
      await _api.updateSession(
        s.id,
        startAt: slot.startAt,
        reason: 'Usulan jam lain dari front desk',
      );
      await _api.setStatus(s.id, SessionStatus.scheduled);
    }, 'Dijadwalkan ${Fmt.dayShort(slot.startAt)} ${Fmt.time(slot.startAt)}.');
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Booking masuk',
    children: [
      OlAsync<List<Session>>(
        key: ValueKey(_gen),
        load: _load,
        builder: (context, items, _) {
          final c = context.ol;
          final t = context.olText;
          if (items.isEmpty) {
            return const [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptyInbox,
                  title: 'Tidak ada booking menunggu',
                  message: 'Booking yang menunggu konfirmasi muncul di sini.',
                ),
              ),
            ];
          }
          return [
            Text('${items.length} menunggu konfirmasi', style: t.caption),
            for (final s in items)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (s.isNewPatient)
                          const OlTag('Pasien baru', tone: OlTagTone.outline),
                        if (s.isHomeVisit) ...[
                          const SizedBox(width: 6),
                          const OlTag('Home visit', tone: OlTagTone.warn),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.patientName,
                      style: t.heading.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${s.serviceName} · '),
                          TextSpan(
                            text:
                                '${Fmt.dayShort(s.startAt)} · ${Fmt.time(s.startAt)}',
                            style: t.mono.copyWith(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' · ${s.therapistName}'),
                        ],
                      ),
                      style: t.body.copyWith(fontSize: 15),
                    ),
                    if (s.note != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '"${s.note}"',
                        style: t.body.copyWith(color: c.muted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OlFootRow(
                      children: [
                        OlButton.secondary(
                          label: 'Tolak',
                          small: true,
                          onPressed: () => _reject(s),
                        ),
                        OlButton.secondary(
                          label: 'Jam lain',
                          small: true,
                          onPressed: () => _propose(s),
                        ),
                        OlButton(
                          label: 'Terima',
                          small: true,
                          onPressed: () => _accept(s),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ];
        },
      ),
    ],
  );
}
