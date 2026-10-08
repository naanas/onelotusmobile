import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

class _Booking {
  _Booking(
    this.source,
    this.name,
    this.service,
    this.when,
    this.who,
    this.ago, {
    this.badge,
    this.badgeTone = OlTagTone.ok,
    this.note,
    this.slotTaken = false,
    this.stale,
  });
  final String source;
  final String name;
  final String service;
  final String when;
  final String who;
  final String ago;
  final String? badge;
  final OlTagTone badgeTone;
  final String? note;
  final bool slotTaken;
  final String? stale;
}

/// KS-07 Booking masuk (website & aplikasi pasien): Terima · Usulkan jam lain · Tolak (wajib alasan).
class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _items = [
    _Booking(
      'Aplikasi',
      'Rina Setiawati',
      'Masase cedera ringan',
      'Kam 8 Okt · 16.00',
      'Dimas',
      '12 mnt lalu',
      badge: 'DP lunas',
      note: '"Mau lanjut sesi terakhir paket."',
    ),
    _Booking(
      'Website',
      'Hendra Gunawan',
      'Adjustment Therapy',
      'Jum 9 Okt · 10.00',
      'siapa saja',
      '1 jam lalu',
      badge: 'Pasien baru',
      badgeTone: OlTagTone.outline,
      slotTaken: true,
    ),
    _Booking(
      'Aplikasi',
      'Budi Hartono',
      'Relaksasi Premium',
      'Sab 10 Okt · 13.00',
      'Sukun',
      '3 jam lalu',
      badge: 'Home visit',
      badgeTone: OlTagTone.warn,
      stale: 'Belum direspons 3 jam',
    ),
  ];

  void _done(_Booking b, String msg) {
    setState(() => _items.remove(b));
    context.feedback.success(msg);
  }

  Future<void> _reject(_Booking b) async {
    final r = await context.feedback.choose(
      ConfirmSpec(
        title: 'Tolak booking ${b.name}?',
        message: 'Pasien akan diberi tahu beserta alasannya.',
        confirmLabel: 'Tolak booking',
        reasonLabel: 'Alasan',
      ),
    );
    if (r.confirmed) _done(b, 'Booking ditolak. Pasien sudah diberi tahu.');
  }

  Future<void> _propose(_Booking b) async {
    final slot = await context.feedback.sheet<String>(
      title: 'Usulkan jam lain',
      message: '${b.name} · ${b.service}',
      actions: const [
        SheetAction(
          'Jum 9 Okt · 13.00',
          'Jum 9 Okt · 13.00',
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Jum 9 Okt · 15.00',
          'Jum 9 Okt · 15.00',
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Sab 10 Okt · 09.00',
          'Sab 10 Okt · 09.00',
          variant: OlButtonVariant.secondary,
        ),
      ],
    );
    if (slot != null) _done(b, 'Usulan $slot terkirim ke pasien.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Booking masuk',
      context_: '${_items.length} menunggu konfirmasi',
      children: [
        if (_items.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptyInbox,
              title: 'Tidak ada booking menunggu',
              message:
                  'Booking baru dari website & aplikasi pasien muncul di sini.',
            ),
          ),
        for (final b in _items)
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    OlTag(b.source, tone: OlTagTone.muted),
                    const SizedBox(width: 6),
                    if (b.badge != null) OlTag(b.badge!, tone: b.badgeTone),
                    const Spacer(),
                    Text(b.ago, style: t.body.copyWith(color: c.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(b.name, style: t.heading.copyWith(fontSize: 17)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${b.service} · '),
                      TextSpan(
                        text: b.when,
                        style: t.mono.copyWith(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' · ${b.who}'),
                    ],
                  ),
                  style: t.body.copyWith(fontSize: 15),
                ),
                if (b.note != null) ...[
                  const SizedBox(height: 6),
                  Text(b.note!, style: t.body.copyWith(color: c.muted)),
                ],
                if (b.slotTaken) ...[
                  const SizedBox(height: 8),
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
                      'Slot yang diminta sudah terisi — usulkan jam lain',
                      style: t.caption.copyWith(
                        fontSize: 13,
                        color: c.warn,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (b.stale != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    b.stale!,
                    style: t.body.copyWith(
                      color: c.warn,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OlFootRow(
                  children: [
                    if (!b.slotTaken)
                      OlButton(
                        label: 'Terima',
                        small: true,
                        onPressed: () =>
                            _done(b, 'Booking diterima. Pasien diberi tahu.'),
                      ),
                    if (b.slotTaken)
                      OlButton(
                        label: 'Usulkan jam lain',
                        small: true,
                        onPressed: () => _propose(b),
                      )
                    else
                      OlButton.secondary(
                        label: 'Usulkan jam',
                        small: true,
                        onPressed: () => _propose(b),
                      ),
                    OlButton(
                      label: 'Tolak',
                      small: true,
                      variant: OlButtonVariant.dangerSecondary,
                      onPressed: () => _reject(b),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
