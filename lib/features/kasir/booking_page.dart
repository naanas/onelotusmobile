import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../shared/slot_sheet.dart';
import 'billing_common.dart';
import 'intake_xray.dart';

/// KS-07 Booking masuk: booking dari aplikasi pasien / website (`GET /v1/bookings`).
/// Terima → backend membuat sesi; Jam lain → pasien memilih di aplikasinya; Tolak → wajib alasan.
class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key});

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  int _gen = 0;
  String _status = 'pending';

  BillingApi get _api => ref.read(billingApiProvider);

  Future<List<BookingReqV>> _load() => _api.bookings(
    status: _status,
    branchId: ref.read(authProvider).activeBranch?.id,
  );

  Future<void> _done(Future<Object?> Function() action, String ok) async {
    final r = await runApi(context, action);
    if (r == null || !mounted) return;
    context.feedback.success(ok);
    setState(() => _gen++);
  }

  Future<void> _accept(BookingReqV b) => _done(
    () => _api.acceptBooking(b.id),
    'Booking ${b.displayName} diterima. Sesi masuk jadwal.',
  );

  Future<void> _reject(BookingReqV b) async {
    final r = await context.feedback.choose(
      ConfirmSpec(
        title: 'Tolak booking ${b.displayName}?',
        message: 'Pasien diberi tahu beserta alasannya.',
        confirmLabel: 'Tolak booking',
        reasonLabel: 'Alasan',
      ),
    );
    if (!r.confirmed) return;
    await _done(
      () => _api.rejectBooking(b.id, r.reason ?? ''),
      'Booking ditolak.',
    );
  }

  Future<void> _propose(BookingReqV b) async {
    final branchId = b.branchId ?? ref.read(authProvider).activeBranch?.id;
    if (branchId == null || b.serviceId == null) return;
    final slot = await pickSlot(
      context,
      title: 'Usulkan jam lain',
      branchId: branchId,
      serviceId: b.serviceId!,
      homeVisit: b.homeVisit,
    );
    if (slot == null || !mounted) return;
    await _done(
      () => _api.proposeBooking(
        b.id,
        slot.startAt,
        reason: 'Usulan jam lain dari front desk',
      ),
      'Usulan ${Fmt.dayShort(slot.startAt)} ${Fmt.time(slot.startAt)} dikirim ke pasien.',
    );
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Booking masuk',
    children: [
      OlSegmented<String>(
        segments: const {
          'pending': 'Menunggu',
          'proposed': 'Diusulkan',
          'accepted': 'Diterima',
        },
        value: _status,
        onChanged: (v) => setState(() => _status = v),
      ),
      OlAsync<List<BookingReqV>>(
        key: ValueKey((_gen, _status)),
        load: _load,
        builder: (context, items, _) {
          final c = context.ol;
          final t = context.olText;
          if (items.isEmpty) {
            return [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptyInbox,
                  title: switch (_status) {
                    'proposed' => 'Tidak ada usulan jam lain',
                    'accepted' => 'Belum ada booking diterima',
                    _ => 'Tidak ada booking menunggu',
                  },
                  message:
                      'Booking dari aplikasi pasien dan website muncul di sini.',
                ),
              ),
            ];
          }
          return [
            Text('${items.length} booking', style: t.caption),
            for (final b in items)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        OlTag(
                          bookingSourceLabels[b.source] ?? b.source,
                          tone: OlTagTone.muted,
                        ),
                        if (b.isNewPatient)
                          const OlTag('Pasien baru', tone: OlTagTone.outline),
                        if (b.homeVisit)
                          const OlTag('Home visit', tone: OlTagTone.warn),
                        if (!b.slotStillFree)
                          const OlTag(
                            'Slot sudah terisi',
                            tone: OlTagTone.crit,
                          ),
                        if (b.dpStatus != null)
                          OlTag(
                            'DP: ${invoiceStatusLabels[b.dpStatus] ?? b.dpStatus}',
                            tone: OlTagTone.outline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      b.patientNumber == null
                          ? b.displayName
                          : '${b.displayName} · ${Fmt.patientNo(b.patientNumber!)}',
                      style: t.heading.copyWith(fontSize: 17),
                    ),
                    if (b.isNewPatient && b.guestPhone != null)
                      Text(
                        b.guestPhone!,
                        style: t.body.copyWith(color: c.muted),
                      ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${b.serviceName} · '),
                          TextSpan(
                            text:
                                '${Fmt.dayShort(b.start.toLocal())} · ${Fmt.time(b.start.toLocal())}',
                            style: t.mono.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (b.proposedStart != null)
                            const TextSpan(text: ' (usulan)'),
                        ],
                      ),
                      style: t.body.copyWith(fontSize: 15),
                    ),
                    if (b.homeVisit) ...[
                      const SizedBox(height: OlSpace.sm),
                      _HomeVisitInfo(bookingId: b.id),
                    ],
                    IntakeXray.booking(bookingId: b.id),
                    if (b.note != null && b.note!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '"${b.note}"',
                        style: t.body.copyWith(color: c.muted),
                      ),
                    ],
                    if (b.createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Masuk ${Fmt.dayShort(b.createdAt!.toLocal())} ${Fmt.time(b.createdAt!.toLocal())}',
                        style: t.caption.copyWith(color: c.faint),
                      ),
                    ],
                    if (b.status == 'pending') ...[
                      const SizedBox(height: 12),
                      OlFootRow(
                        children: [
                          OlButton.secondary(
                            label: 'Tolak',
                            small: true,
                            onPressed: () => _reject(b),
                          ),
                          OlButton.secondary(
                            label: 'Jam lain',
                            small: true,
                            onPressed: () => _propose(b),
                          ),
                          OlButton(
                            label: 'Terima',
                            small: true,
                            onPressed: () => _accept(b),
                          ),
                        ],
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

/// Alamat, jarak, & estimasi transport booking home visit — bahan front desk sebelum menerima.
class _HomeVisitInfo extends ConsumerStatefulWidget {
  const _HomeVisitInfo({required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<_HomeVisitInfo> createState() => _HomeVisitInfoState();
}

class _HomeVisitInfoState extends ConsumerState<_HomeVisitInfo> {
  late final Future<BookingHomeVisitV> _info = ref.read(billingApiProvider).bookingHomeVisit(widget.bookingId);

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return FutureBuilder<BookingHomeVisitV>(
      future: _info,
      builder: (context, snap) {
        final h = snap.data;
        if (h == null) {
          return snap.hasError
              ? Text('Info alamat belum bisa dimuat.', style: t.caption.copyWith(color: c.muted))
              : const Skeleton(height: 54);
        }
        final km = h.distanceKm?.toStringAsFixed(1).replaceAll('.', ',');
        return Container(
          padding: const EdgeInsets.all(OlSpace.md),
          decoration: BoxDecoration(
            color: h.inArea ? c.surfaceAlt : c.critSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: OlIcon(OlIcons.pin, size: 16, color: h.inArea ? c.brandDeep : c.crit),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [h.address, if (h.landmark?.isNotEmpty ?? false) h.landmark!].join(' · '),
                      style: t.body.copyWith(fontSize: 14.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  if (km != null) '$km km dari cabang',
                  h.transportFee > 0 ? 'transport ${Fmt.money(h.transportFee)}' : 'transport gratis',
                ].join(' · '),
                style: t.caption.copyWith(color: c.muted, fontWeight: FontWeight.w600),
              ),
              if (!h.inArea)
                Text(
                  'Di luar jangkauan home visit${h.maxKm != null ? ' (maks. ${h.maxKm!.toStringAsFixed(0)} km)' : ''}.',
                  style: t.caption.copyWith(color: c.crit, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        );
      },
    );
  }
}
