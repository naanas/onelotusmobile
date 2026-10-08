import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Period { today, week, month, custom }

/// Angka contoh per periode (CLAUDE.md: data mockup hanya ilustrasi).
typedef _Summary = ({
  String omzetLabel,
  String omzet,
  String trend,
  bool up,
  List<OlBar> bars,
  int returning,
  int occupancy,
  List<(String, int)> sessions,
});

const _summaries = <_Period, _Summary>{
  _Period.today: (
    omzetLabel: 'Omzet hari ini',
    omzet: 'Rp2,2 jt',
    trend: '8%',
    up: true,
    bars: [
      OlBar('09', 0.4),
      OlBar('11', 0.6),
      OlBar('13', 0.3),
      OlBar('15', 0.5),
      OlBar('17', 0.4, highlight: true),
    ],
    returning: 71,
    occupancy: 78,
    sessions: [('Dimas', 6), ('Fajar', 5), ('Laras', 4)],
  ),
  _Period.week: (
    omzetLabel: 'Omzet minggu ini',
    omzet: 'Rp9,4 jt',
    trend: '9%',
    up: true,
    bars: [
      OlBar('Kam', 1.3),
      OlBar('Jum', 1.6),
      OlBar('Sab', 2.1),
      OlBar('Min', 0.4, dim: true),
      OlBar('Sen', 1.8),
      OlBar('Sel', 2.2, highlight: true),
    ],
    returning: 66,
    occupancy: 80,
    sessions: [('Dimas', 24), ('Fajar', 21), ('Laras', 17)],
  ),
  _Period.month: (
    omzetLabel: 'Omzet bulan ini',
    omzet: 'Rp38,4 jt',
    trend: '12%',
    up: true,
    bars: [
      OlBar('Mg 1', 8.1),
      OlBar('Mg 2', 9.6),
      OlBar('Mg 3', 10.2),
      OlBar('Mg 4', 10.5, highlight: true),
    ],
    returning: 64,
    occupancy: 81,
    sessions: [('Dimas', 92), ('Fajar', 78), ('Laras', 64)],
  ),
  _Period.custom: (
    omzetLabel: 'Omzet Jul–Sep 2026',
    omzet: 'Rp104,7 jt',
    trend: '3%',
    up: false,
    bars: [
      OlBar('Jul', 36.1),
      OlBar('Agu', 34.2),
      OlBar('Sep', 34.4, highlight: true),
    ],
    returning: 61,
    occupancy: 76,
    sessions: [('Dimas', 270), ('Fajar', 231), ('Laras', 198)],
  ),
};

/// OW-01 Ringkasan bisnis (tab Ringkasan owner): omzet per periode, retensi,
/// okupansi, sesi per terapis, peringatan, dan pintasan Kelola.
class RingkasanPage extends StatefulWidget {
  const RingkasanPage({super.key});

  @override
  State<RingkasanPage> createState() => _RingkasanPageState();
}

class _RingkasanPageState extends State<RingkasanPage> {
  _Period _period = _Period.month;

  Future<void> _more() async {
    final route = await context.feedback.sheet<String>(
      title: 'Kelola lainnya',
      actions: const [
        SheetAction(
          'Rekap komisi',
          Routes.ownerKomisi,
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Poin & referral',
          Routes.ownerPoin,
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Template pesan',
          Routes.ownerTemplate,
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Pustaka latihan',
          Routes.ownerPustaka,
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Pengumuman',
          Routes.ownerPengumuman,
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Cabang & ruang',
          Routes.ownerCabang,
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Audit log',
          Routes.ownerAudit,
          variant: OlButtonVariant.secondary,
        ),
        SheetAction(
          'Rekonsiliasi gateway',
          Routes.ownerRekonsiliasi,
          variant: OlButtonVariant.secondary,
        ),
      ],
    );
    if (route != null && mounted) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final s = _summaries[_period]!;
    final maxSessions = s.sessions.first.$2;

    return OlPageBody(
      heroOverlap: true,
      header: OlAppHeader(
        hero: true,
        title: 'Ringkasan bisnis',
        context_: 'Oktober 2026 · semua cabang · diperbarui 20.05',
        actions: [
          OlIconButton(
            icon: OlIcons.checkCircle,
            semanticLabel: 'Persetujuan',
            badge: 3,
            onHero: true,
            onPressed: () => context.push(Routes.ownerPersetujuan),
          ),
          const SizedBox(width: 4),
          OlIconButton(
            icon: OlIcons.bell,
            semanticLabel: 'Notifikasi',
            onHero: true,
            onPressed: () => context.push(Routes.notifications),
          ),
        ],
        bottom: OlSegmented<_Period>(
          segments: const {
            _Period.today: 'Hari ini',
            _Period.week: 'Minggu',
            _Period.month: 'Bulan',
            _Period.custom: 'Custom',
          },
          value: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
      ),
      children: [
        const FeedbackBannerHost(),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.omzetLabel,
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ),
                  OlTag(
                    '${s.up ? '▲' : '▼'} ${s.trend}',
                    tone: s.up ? OlTagTone.ok : OlTagTone.crit,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.omzet,
                style: t.mono.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              OlBarChart(
                height: 96,
                bars: s.bars,
                semanticLabel:
                    '${s.omzetLabel} ${s.omzet}. ${[for (final b in s.bars) '${b.label} ${b.value}'].join(', ')} juta rupiah.',
              ),
              const SizedBox(height: 4),
              Text(
                'dalam juta rupiah',
                style: t.body.copyWith(fontSize: 13.5, color: c.muted),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: '${s.returning}%',
                label: 'pasien datang lagi',
              ),
            ),
            const SizedBox(width: OlSpace.gap),
            Expanded(
              child: _Stat(
                value: '${s.occupancy}%',
                label: 'slot terapis terisi',
              ),
            ),
          ],
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sesi per terapis', style: t.heading),
              const SizedBox(height: 6),
              for (final (name, n) in s.sessions)
                OlMeterRow(label: name, value: n, max: maxSessions),
            ],
          ),
        ),
        _AlertCard(onTap: () => context.push(Routes.ownerPengingat)),
        OlCard(
          onTap: () => context.push(Routes.kasirPiutang),
          semanticLabel:
              '2 tagihan belum lunas lebih dari 7 hari, Rp490.000. Kirim link bayar.',
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2 tagihan belum lunas >7 hari',
                      style: t.bodyStrong.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rp490.000 · kirim link bayar',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              OlIcon(OlIcons.chevronRight, color: c.muted),
            ],
          ),
        ),
        const OlOverline('KELOLA'),
        _ManageGrid(
          items: [
            (OlIcons.users, 'Staf', () => context.push(Routes.ownerStaf)),
            (OlIcons.receipt, 'Harga', () => context.push(Routes.ownerLayanan)),
            (OlIcons.package, 'Paket', () => context.push(Routes.ownerPaket)),
            (
              OlIcons.percent,
              'Komisi',
              () => context.push(Routes.ownerAturanKomisi),
            ),
            (
              OlIcons.voucher,
              'Voucher',
              () => context.push(Routes.ownerVoucher),
            ),
            (OlIcons.grid, 'Lainnya', _more),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return OlCard(
      semanticLabel: '$value $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: t.display.copyWith(fontSize: 28)),
          const SizedBox(height: 2),
          Text(label, style: t.body.copyWith(color: context.ol.muted)),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Semantics(
      container: true,
      button: true,
      label:
          '14 pasien belum kembali lebih dari 30 hari. Kirim pengingat WhatsApp.',
      excludeSemantics: true,
      child: Material(
        color: c.warnSoft,
        borderRadius: BorderRadius.circular(OlRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(OlRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(OlSpace.lg),
            child: Row(
              children: [
                OlIcon(OlIcons.alert, color: c.warn),
                const SizedBox(width: OlSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '14 pasien belum kembali >30 hari',
                        style: t.bodyStrong.copyWith(
                          fontSize: 16,
                          color: c.warn,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kirim pengingat WhatsApp →',
                        style: t.body.copyWith(color: c.warn),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid 3 kolom pintasan Kelola. Tinggi mengikuti isi (aman di teks besar).
class _ManageGrid extends StatelessWidget {
  const _ManageGrid({required this.items});
  final List<(OlIconData, String, VoidCallback)> items;

  @override
  Widget build(BuildContext context) {
    final rows = <List<(OlIconData, String, VoidCallback)>>[
      for (var i = 0; i < items.length; i += 3)
        items.sublist(i, (i + 3).clamp(0, items.length)),
    ];
    return Column(
      children: [
        for (final (ri, row) in rows.indexed) ...[
          if (ri > 0) const SizedBox(height: OlSpace.gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (icon, label, onTap)) in row.indexed) ...[
                  if (i > 0) const SizedBox(width: OlSpace.gap),
                  Expanded(
                    child: OlCard(
                      onTap: onTap,
                      semanticLabel: label,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 8,
                      ),
                      child: Column(
                        children: [
                          OlIcon(icon, color: context.ol.brand),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: context.olText.bodyStrong.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
