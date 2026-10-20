import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Period { today, week, month }

typedef _Data = ({List<Session> sessions, int approvals});

/// OW-01 Ringkasan (tab Ringkasan owner): angka operasional dari jadwal cabang
/// (`GET /v1/sessions`): sesi selesai, tidak datang, dibatalkan, booking menunggu, sesi per terapis,
/// dan persetujuan tertunda. Omzet & retensi menunggu modul pembayaran/laporan.
class RingkasanPage extends ConsumerStatefulWidget {
  const RingkasanPage({super.key});

  @override
  ConsumerState<RingkasanPage> createState() => _RingkasanPageState();
}

class _RingkasanPageState extends ConsumerState<RingkasanPage> {
  _Period _period = _Period.week;
  int _gen = 0;

  static const _finished = {
    SessionStatus.done,
    SessionStatus.unpaid,
    SessionStatus.paid,
  };

  (DateTime, DateTime) get _range {
    final today = DateUtils.dateOnly(DateTime.now());
    final to = today.add(const Duration(days: 1));
    return switch (_period) {
      _Period.today => (today, to),
      _Period.week => (to.subtract(const Duration(days: 7)), to),
      _Period.month => (to.subtract(const Duration(days: 30)), to),
    };
  }

  Future<_Data> _load() async {
    final api = ref.read(oneLotusApiProvider);
    final branch = ref.read(authProvider).activeBranch!;
    final (from, to) = _range;
    final r = await (
      api.sessions(branchId: branch.id, from: from, to: to),
      api.leaves(status: 'pending'),
      api.passwordResets(),
    ).wait;
    return (sessions: r.$1, approvals: r.$2.length + r.$3.length);
  }

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
          'Kirim pengingat',
          Routes.ownerPengingat,
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

  List<OlBar> _bars(List<Session> done) {
    final (from, _) = _range;
    if (_period == _Period.today) {
      final byHour = <int, int>{};
      for (final s in done) {
        byHour[s.startAt.hour] = (byHour[s.startAt.hour] ?? 0) + 1;
      }
      return [
        for (var h = 8; h < 20; h += 2)
          OlBar(
            h.toString().padLeft(2, '0'),
            ((byHour[h] ?? 0) + (byHour[h + 1] ?? 0)).toDouble(),
          ),
      ];
    }
    final days = _period == _Period.week ? 7 : 30;
    final step = _period == _Period.week ? 1 : 5;
    return [
      for (var i = 0; i < days; i += step)
        OlBar(
          _period == _Period.week
              ? DateFormat('EEE', 'id_ID').format(from.add(Duration(days: i)))
              : '${from.add(Duration(days: i)).day}',
          done
              .where((s) {
                final d = DateUtils.dateOnly(s.startAt).difference(from).inDays;
                return d >= i && d < i + step;
              })
              .length
              .toDouble(),
          highlight: i + step >= days,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    Widget chip(String l, _Period p) => OlChip(
      label: l,
      selected: _period == p,
      onTap: () => setState(() {
        _period = p;
        _gen++;
      }),
    );
    return OlPageBody(
      heroOverlap: true,
      header: OlAppHeader(
        hero: true,
        title: 'Ringkasan',
        context_: ref.watch(authProvider.select((a) => a.activeBranch?.name)),
        actions: [
          OlIconButton(
            icon: OlIcons.bell,
            semanticLabel: 'Notifikasi',
            onHero: true,
            onPressed: () => context.push(Routes.notifications),
          ),
          OlIconButton(
            icon: OlIcons.checkCircle,
            semanticLabel: 'Persetujuan',
            onHero: true,
            onPressed: () => context.push(Routes.ownerPersetujuan),
          ),
        ],
      ),
      children: [
        Wrap(
          spacing: OlSpace.sm,
          children: [
            chip('Hari ini', _Period.today),
            chip('7 hari', _Period.week),
            chip('30 hari', _Period.month),
          ],
        ),
        OlAsync<_Data>(
          key: ValueKey(_gen),
          load: _load,
          builder: (context, d, _) {
            final done = d.sessions
                .where((s) => _finished.contains(s.status))
                .toList();
            final noShow = d.sessions
                .where((s) => s.status == SessionStatus.noShow)
                .length;
            final cancelled = d.sessions
                .where((s) => s.status == SessionStatus.cancelled)
                .length;
            final waiting = d.sessions
                .where((s) => s.status == SessionStatus.awaitingConfirmation)
                .length;
            final perTherapist = <String, int>{};
            for (final s in done) {
              perTherapist[s.therapistName] =
                  (perTherapist[s.therapistName] ?? 0) + 1;
            }
            final ranked = perTherapist.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            return [
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: '${done.length}',
                      label: 'sesi selesai',
                    ),
                  ),
                  const SizedBox(width: OlSpace.md),
                  Expanded(
                    child: _Stat(value: '$noShow', label: 'tidak datang'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _Stat(value: '$cancelled', label: 'dibatalkan'),
                  ),
                  const SizedBox(width: OlSpace.md),
                  Expanded(
                    child: _Stat(value: '$waiting', label: 'booking menunggu'),
                  ),
                ],
              ),
              if (done.isNotEmpty)
                OlCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Sesi selesai', style: t.heading),
                      const SizedBox(height: OlSpace.md),
                      OlBarChart(
                        bars: _bars(done),
                        semanticLabel: 'Grafik sesi selesai',
                      ),
                    ],
                  ),
                ),
              if (ranked.isNotEmpty)
                OlCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Sesi per terapis', style: t.heading),
                      const SizedBox(height: OlSpace.md),
                      for (final e in ranked)
                        OlMeterRow(
                          label: e.key,
                          value: e.value,
                          max: ranked.first.value,
                        ),
                    ],
                  ),
                ),
              if (d.approvals > 0)
                OlCard(
                  onTap: () => context.push(Routes.ownerPersetujuan),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${d.approvals} menunggu persetujuan',
                          style: t.bodyStrong.copyWith(fontSize: 16),
                        ),
                      ),
                      OlIcon(OlIcons.chevronRight, color: c.muted),
                    ],
                  ),
                ),
              OlButton.text(
                label: 'Omzet, retensi & piutang di tab Laporan',
                icon: OlIcons.report,
                onPressed: () => context.go(Routes.ownerLaporan),
                expand: true,
              ),
            ];
          },
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
