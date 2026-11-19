import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Kartu permintaan booking yang belum jadi sesi (Jadwal saya › Mendatang):
/// - menunggu konfirmasi klinik (home visit: estimasi biaya),
/// - klinik mengusulkan jam lain → [onAccept] "Terima jam usulan" / [onChange] "Pilih jam lain",
/// - ditolak / kedaluwarsa → alasan + [onRebook].
class BookingRequestCard extends StatelessWidget {
  const BookingRequestCard({
    super.key,
    required this.request,
    this.onAccept,
    this.onChange,
    this.onRebook,
    this.busy = false,
  });

  final BookingRequestV request;
  final VoidCallback? onAccept, onChange, onRebook;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final r = request;
    final (label, tone) = switch (r.status) {
      'proposed' => ('Klinik usul jam lain', OlTagTone.brand),
      'rejected' => ('Tidak dapat diterima', OlTagTone.crit),
      'expired' => ('Kedaluwarsa', OlTagTone.muted),
      _ => (r.homeVisit ? 'Menunggu konfirmasi klinik' : 'Menunggu konfirmasi', OlTagTone.warn),
    };
    final ended = r.status == 'rejected' || r.status == 'expired';
    String when(DateTime d) => '${Fmt.date(d.toLocal())} · ${Fmt.time(d.toLocal())}';

    return OlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OlTag(label, tone: tone),
              const Spacer(),
              if (r.homeVisit) const OlTag('Home visit', tone: OlTagTone.outline, icon: OlIcons.homeVisit),
            ],
          ),
          const SizedBox(height: 10),
          if (r.status == 'proposed' && r.proposedStart != null) ...[
            Text(when(r.proposedStart!), style: t.heading.copyWith(fontSize: 17)),
            Text(
              'Anda meminta ${when(r.requestedStart)}',
              style: t.caption.copyWith(color: c.muted, decoration: TextDecoration.lineThrough),
            ),
          ] else
            Text(
              when(r.requestedStart),
              style: t.heading.copyWith(fontSize: 17, color: ended ? c.muted : null),
            ),
          const SizedBox(height: 4),
          Text('${r.serviceName} · ${r.durationMin} mnt', style: t.body.copyWith(color: c.muted)),
          if (r.address != null) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: OlIcon(OlIcons.pin, size: 16, color: c.muted),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(r.address!, style: t.body.copyWith(fontSize: 14.5))),
              ],
            ),
          ],
          if (r.estimate != null && !ended) ...[
            const SizedBox(height: OlSpace.md),
            HomeVisitEstimateBox(estimate: r.estimate!),
          ],
          if (r.status == 'pending') ...[
            const SizedBox(height: OlSpace.sm),
            Text(
              r.homeVisit
                  ? 'Klinik sedang mencarikan terapis untuk jam ini. Anda akan mendapat notifikasi begitu dikonfirmasi.'
                  : 'Klinik akan mengonfirmasi jadwal ini. Anda akan mendapat notifikasi.',
              style: t.caption.copyWith(color: c.muted),
            ),
          ],
          if (ended && (r.rejectReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: OlSpace.sm),
            OlBanner(tone: OlBannerTone.crit, message: 'Alasan klinik: ${r.rejectReason}'),
          ],
          if (r.status == 'proposed') ...[
            const SizedBox(height: OlSpace.md),
            OlButton(label: 'Terima jam usulan', loading: busy, onPressed: onAccept),
            const SizedBox(height: OlSpace.xs),
            OlButton.text(label: 'Pilih jam lain / batalkan', onPressed: busy ? null : onChange),
          ] else if (r.status == 'pending') ...[
            const SizedBox(height: OlSpace.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: OlButton.text(label: 'Ubah / batalkan', small: true, onPressed: onChange),
            ),
          ] else if (ended && onRebook != null) ...[
            const SizedBox(height: OlSpace.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: OlButton.text(label: 'Booking jadwal lain', small: true, onPressed: onRebook),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rincian perkiraan biaya home visit: layanan + transport (jarak × tarif) = total.
class HomeVisitEstimateBox extends StatelessWidget {
  const HomeVisitEstimateBox({super.key, required this.estimate});
  final HomeVisitEstimateV estimate;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final e = estimate;
    Widget row(String k, String v, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(k, style: (strong ? t.bodyStrong : t.body).copyWith(fontSize: 14))),
          Text(v, style: (strong ? t.bodyStrong : t.body).copyWith(fontSize: 14)),
        ],
      ),
    );
    final km = e.distanceKm.toStringAsFixed(1).replaceAll('.', ',');
    return Container(
      padding: const EdgeInsets.all(OlSpace.md),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PERKIRAAN BIAYA', style: t.overline.copyWith(color: c.muted)),
          const SizedBox(height: 6),
          row('Layanan', Fmt.money(e.servicePrice)),
          row(
            e.ratePerKm > 0 ? 'Transport ($km km × ${Fmt.money(e.ratePerKm)})' : 'Transport ($km km)',
            e.transportFee > 0 ? Fmt.money(e.transportFee) : 'Gratis',
          ),
          Divider(height: 14, color: c.line),
          row('Total', Fmt.money(e.total), strong: true),
          const SizedBox(height: 4),
          Text(
            'Dibayar setelah sesi selesai (tunai/QRIS ke terapis atau online di aplikasi).',
            style: t.caption.copyWith(color: c.muted),
          ),
          if (!e.inArea)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Alamat di luar jangkauan home visit cabang'
                '${e.maxKm != null ? ' (maks. ${e.maxKm!.toStringAsFixed(0)} km)' : ''}.',
                style: t.caption.copyWith(color: c.crit, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
