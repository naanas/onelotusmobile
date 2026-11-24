import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/common/billing_common.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'slot_picker.dart';

/// PS-11 Ubah / batalkan jadwal sendiri. Batas waktu ubah/batal ditegakkan server (TODO(workshop) §16 no. 8);
/// bila lewat batas, server menolak dan pesan diarahkan ke klinik.
class UbahJadwalPage extends ConsumerStatefulWidget {
  const UbahJadwalPage({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<UbahJadwalPage> createState() => _UbahJadwalPageState();
}

class _UbahJadwalPageState extends ConsumerState<UbahJadwalPage> {
  DateTime? _start;
  bool _busy = false;

  PasienAppApi get _api => ref.read(pasienAppApiProvider);

  /// Booking yang sedang diubah (id dari [UbahJadwalPage.bookingId], bisa id booking atau id sesinya).
  BookingV? _booking;

  /// Jadwal saya mengirim id sesi; permintaan booking mengirim id booking — keduanya dicocokkan di sini.
  /// Null = jadwal dibuat langsung oleh klinik (tanpa booking) → hanya bisa diubah lewat klinik.
  Future<BookingV?> _load() async {
    final list = await _api.bookings();
    final b = list.where((b) => b.id == widget.bookingId || b.sessionId == widget.bookingId).firstOrNull;
    if (mounted) setState(() => _booking = b);
    return b;
  }

  String get _id => _booking?.id ?? widget.bookingId;

  Future<void> _reschedule() async {
    setState(() => _busy = true);
    final b = await runApi(context, () => _api.reschedule(_id, _start!));
    if (!mounted) return;
    setState(() => _busy = false);
    if (b == null) return;
    context.feedback.success('Permintaan ubah jadwal terkirim. Menunggu konfirmasi klinik.');
    context.pop();
  }

  Future<void> _cancel() async {
    final r = await context.feedback.choose(
      const ConfirmSpec(
        title: 'Batalkan jadwal?',
        message: 'Jadwal dibatalkan dan slot dilepas untuk pasien lain.',
        confirmLabel: 'Batalkan jadwal',
        reasonLabel: 'Alasan',
        danger: true,
      ),
    );
    if (!r.confirmed || !mounted) return;
    final b = await runApi(context, () => _api.cancelBooking(_id, r.reason ?? ''));
    if (b == null || !mounted) return;
    context.feedback.success('Jadwal dibatalkan.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    pinnedHeader: true,
    title: 'Ubah jadwal',
    foot: [
      if (_booking != null) ...[
        OlButton(label: 'Minta jadwal baru', loading: _busy, onPressed: _start == null ? null : _reschedule),
        OlButton.text(label: 'Batalkan jadwal', onPressed: _busy ? null : _cancel),
      ],
    ],
    children: [
      OlAsync<BookingV?>(
        load: _load,
        builder: (context, b, _) {
          final t = context.olText;
          final c = context.ol;
          if (b == null) {
            return const [
              OlBanner(
                message: 'Jadwal ini dibuat langsung oleh klinik. Untuk mengubah atau membatalkan, '
                    'hubungi klinik lewat WhatsApp.',
              ),
            ];
          }
          return [
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jadwal sekarang', style: t.caption.copyWith(color: c.muted)),
                  Text('${Fmt.date(b.start.toLocal())} · ${Fmt.time(b.start.toLocal())}', style: t.heading),
                  Text([b.serviceName, bookingStatusLabels[b.status] ?? b.status].join(' · '), style: t.body.copyWith(color: c.muted)),
                ],
              ),
            ),
            if (b.serviceId != null && b.branchId != null) ...[
              const OlSectionHeader(title: 'Pilih waktu baru'),
              SlotPicker(
                branchId: b.branchId!,
                serviceId: b.serviceId!,
                homeVisit: b.homeVisit,
                value: _start,
                onChanged: (v) => setState(() => _start = v),
              ),
            ],
            Text('Batas ubah/batal mengikuti aturan klinik. Bila sudah lewat, hubungi klinik lewat WhatsApp.', style: t.caption.copyWith(color: c.muted)),
          ];
        },
      ),
    ],
  );
}
