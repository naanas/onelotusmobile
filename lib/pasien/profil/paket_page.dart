import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

/// PS-13 Paket & pembayaran:
/// 1. Paket aktif (sisa sesi + masa berlaku),
/// 2. Status pembayaran tagihan yang belum lunas — mengikuti hasil Dupay/PG (menunggu, gagal, kedaluwarsa, …),
/// 3. Riwayat pembelian (lunas → struk).
/// Data tampil langsung dari cache memori, lalu dimuat ulang di belakang.
class PaketPage extends ConsumerStatefulWidget {
  const PaketPage({super.key});

  @override
  ConsumerState<PaketPage> createState() => _PaketPageState();
}

typedef _Data = (List<OwnershipV>, List<InvoiceV>);

class _PaketPageState extends ConsumerState<PaketPage> {
  int _gen = 0;

  PasienAppApi get _api => ref.read(pasienAppApiProvider);

  Future<void> _go(String route) async {
    await context.push(route);
    if (mounted) setState(() => _gen++); // kembali → muat ulang (cache tetap tampil selama memuat)
  }

  _Data? get _cached {
    final p = _api.cached<List<OwnershipV>>('packages');
    final i = _api.cached<List<InvoiceV>>('invoices');
    return p != null && i != null ? (p, i) : null;
  }

  @override
  Widget build(BuildContext context) {
    return OlDetailScaffold(
      pinnedHeader: true,
      title: 'Paket & pembayaran',
      foot: [OlButton.secondary(label: 'Beli paket', icon: OlIcons.package, onPressed: () => _go(PRoutes.beliPaket))],
      children: [
        OlAsync<_Data>(
          key: ValueKey(_gen),
          initialData: _cached,
          load: () => (_api.packages(), _api.invoices()).wait,
          builder: (context, d, _) {
            final (pkgs, invoices) = d;
            final active = [for (final p in pkgs) if (p.status == 'active') p];
            final ended = [for (final p in pkgs) if (p.status != 'active') p];
            final open = [
              for (final i in invoices)
                if (!const {InvoicePayState.paid, InvoicePayState.refunded, InvoicePayState.voided}.contains(i.payState)) i,
            ];
            final history = [for (final i in invoices) if (!open.contains(i)) i];
            return [
              _section(
                'Paket aktif',
                [
                  if (active.isEmpty)
                    _EmptyPackage(onBuy: () => _go(PRoutes.beliPaket))
                  else
                    for (final p in active) _ActivePackageCard(p),
                ],
              ),
              if (open.isNotEmpty)
                _section('Status pembayaran', [for (final i in open) _OpenInvoiceCard(i, onTap: () => _detail(i))]),
              _section(
                'Riwayat pembelian',
                [
                  if (history.isEmpty && ended.isEmpty)
                    Text('Belum ada pembelian.', style: context.olText.body.copyWith(color: context.ol.muted))
                  else ...[
                    if (history.isNotEmpty)
                      OlCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (n, i) in history.indexed)
                              _HistoryRow(i, divider: n < history.length - 1, onTap: () => _detail(i)),
                          ],
                        ),
                      ),
                    if (ended.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        child: Text('PAKET SELESAI', style: context.olText.overline.copyWith(color: context.ol.muted)),
                      ),
                      for (final p in ended) _EndedPackageRow(p),
                    ],
                  ],
                ],
              ),
            ];
          },
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OlSectionHeader(title: title),
      for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(height: OlSpace.sm), w],
    ],
  );

  /// Rincian tagihan + semua percobaan bayar (hasil Dupay/PG) + aksi yang sesuai statusnya.
  Future<void> _detail(InvoiceV inv) async {
    final st = inv.payState;
    if (st == InvoicePayState.paid && inv.receiptId != null) {
      await context.push('${PRoutes.struk}?id=${inv.receiptId}');
      return;
    }
    final action = switch (st) {
      InvoicePayState.waiting => 'Lihat instruksi pembayaran',
      InvoicePayState.unpaid => 'Bayar sekarang',
      _ when st.ended => 'Bayar lagi',
      _ => null,
    };
    final go = await context.feedback.sheet<bool>(
      title: inv.number ?? 'Tagihan',
      child: _InvoiceDetail(inv),
      actions: [
        if (action != null && inv.payable) SheetAction(action, true),
        const SheetAction('Tutup', false, variant: OlButtonVariant.text),
      ],
    );
    if (go == true && mounted) await _go('${PRoutes.bayar}?invoice=${inv.id}');
  }
}

// ── Paket ─────────────────────────────────────────────────────────────────

class _ActivePackageCard extends StatelessWidget {
  const _ActivePackageCard(this.p);
  final OwnershipV p;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final ratio = p.total <= 0 ? 0.0 : (p.remaining / p.total).clamp(0.0, 1.0);
    final daysLeft = p.expiresOn?.difference(DateTime.now()).inDays;
    final low = p.total > 0 && p.remaining <= 2;
    final expiring = daysLeft != null && daysLeft <= 14;
    return Container(
      padding: const EdgeInsets.all(OlSpace.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(OlRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.brand, c.brandDeep],
        ),
        boxShadow: OlShadow.brandButton,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: const OlIcon(OlIcons.package, color: Colors.white, size: 20, weight: OlIconWeight.duotone),
              ),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Text(p.name, style: t.heading.copyWith(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              _Pill(low ? 'Hampir habis' : 'Aktif', warn: low),
            ],
          ),
          const SizedBox(height: OlSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: p.remaining.toDouble()),
                duration: OlMotion.of(context, const Duration(milliseconds: 700)),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  '${v.round()}',
                  style: t.display.copyWith(color: Colors.white, height: 1),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  p.total > 0 ? 'dari ${p.total} sesi tersisa' : 'sesi tersisa',
                  style: t.body.copyWith(color: Colors.white.withValues(alpha: .85)),
                ),
              ),
            ],
          ),
          if (p.total > 0) ...[
            const SizedBox(height: OlSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: OlMotion.of(context, const Duration(milliseconds: 800)),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: .22),
                ),
              ),
            ),
          ],
          if (p.expiresOn != null) ...[
            const SizedBox(height: OlSpace.md),
            Row(
              children: [
                OlIcon(OlIcons.clock, size: 15, color: Colors.white.withValues(alpha: expiring ? 1 : .8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    expiring && daysLeft >= 0
                        ? 'Berakhir ${daysLeft == 0 ? 'hari ini' : 'dalam $daysLeft hari'} · ${Fmt.dateNoDay(p.expiresOn!)}'
                        : 'Berlaku sampai ${Fmt.dateNoDay(p.expiresOn!)}',
                    style: t.caption.copyWith(
                      color: Colors.white.withValues(alpha: expiring ? 1 : .8),
                      fontWeight: expiring ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.warn = false});
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: warn ? context.ol.warnSoft : Colors.white.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: context.olText.caption.copyWith(color: warn ? context.ol.warn : Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}

class _EmptyPackage extends StatelessWidget {
  const _EmptyPackage({required this.onBuy});
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: OlIcon(OlIcons.package, color: c.brandDeep, weight: OlIconWeight.duotone),
          ),
          const SizedBox(width: OlSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Belum ada paket aktif', style: t.bodyStrong),
                Text('Paket membuat tiap sesi lebih hemat.', style: t.caption.copyWith(color: c.muted)),
              ],
            ),
          ),
          OlButton(label: 'Lihat', expand: false, onPressed: onBuy),
        ],
      ),
    );
  }
}

class _EndedPackageRow extends StatelessWidget {
  const _EndedPackageRow(this.p);
  final OwnershipV p;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlCard(
      padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg, vertical: OlSpace.md),
      child: Row(
        children: [
          OlIcon(OlIcons.package, color: c.faint, size: 20),
          const SizedBox(width: OlSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: t.bodyStrong),
                Text(
                  [
                    if (p.total > 0) '${p.total - p.remaining}/${p.total} sesi terpakai',
                    if (p.expiresOn != null) 's.d. ${Fmt.dateNoDay(p.expiresOn!)}',
                  ].join(' · '),
                  style: t.caption.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          OlTag(
            switch (p.status) {
              'expired' => 'Kedaluwarsa',
              'used_up' => 'Habis',
              'pending_payment' => 'Menunggu bayar',
              _ => p.status,
            },
            tone: OlTagTone.muted,
          ),
        ],
      ),
    );
  }
}

// ── Tagihan ───────────────────────────────────────────────────────────────

OlTagTone _tone(InvoicePayState s) => switch (s) {
  InvoicePayState.paid => OlTagTone.ok,
  InvoicePayState.waiting || InvoicePayState.verifying => OlTagTone.warn,
  InvoicePayState.failed || InvoicePayState.rejected || InvoicePayState.expired => OlTagTone.crit,
  InvoicePayState.unpaid => OlTagTone.brand,
  _ => OlTagTone.muted,
};

String _methodLabel(PaymentV p) => switch (p.method) {
  'va' when p.vaBank != null => '${p.vaBank!.toUpperCase()} Virtual Account',
  _ => paymentMethodLabels[p.method] ?? p.method,
};

String _when(DateTime d) => '${Fmt.dayShort(d.toLocal())} ${Fmt.time(d.toLocal())}';

String _invoiceTitle(InvoiceV i) {
  final pkg = i.kind == 'package' ? i.items.where((x) => x.description.isNotEmpty).firstOrNull?.description : null;
  return pkg ?? invoiceKindLabels[i.kind] ?? 'Tagihan';
}

class _OpenInvoiceCard extends StatelessWidget {
  const _OpenInvoiceCard(this.inv, {required this.onTap});
  final InvoiceV inv;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final st = inv.payState;
    final last = inv.pendingPayment ?? inv.lastAttempt;
    final note = switch (st) {
      InvoicePayState.waiting when last?.expiresAt != null =>
        '${_methodLabel(last!)} · bayar sebelum ${_when(last.expiresAt!)}',
      InvoicePayState.waiting => '${_methodLabel(last!)} · menunggu pembayaran',
      InvoicePayState.verifying => 'Bukti transfer sedang dicek klinik',
      _ when st.ended && last != null =>
        '${_methodLabel(last)} ${st == InvoicePayState.failed ? 'gagal' : st.label.toLowerCase()}'
            '${last.createdAt != null ? ' · ${_when(last.createdAt!)}' : ''}. Silakan bayar lagi.',
      _ => inv.sessionDate != null ? 'Sesi ${Fmt.dayShort(inv.sessionDate!)}' : 'Belum ada pembayaran',
    };
    final (Color accent, OlIconData icon) = switch (st) {
      InvoicePayState.waiting || InvoicePayState.verifying => (c.warn, OlIcons.clock),
      _ when st.ended => (c.crit, OlIcons.alert),
      _ => (c.brand, OlIcons.receipt),
    };
    return OlCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(OlRadius.card)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(OlSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        OlIcon(icon, size: 18, color: accent),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_invoiceTitle(inv), style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        OlTag(st.label, tone: _tone(st)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(note, style: t.caption.copyWith(color: st.ended ? c.crit : c.muted)),
                    const SizedBox(height: OlSpace.sm),
                    Row(
                      children: [
                        Expanded(child: Text(inv.number ?? '', style: t.mono.copyWith(color: c.faint, fontSize: 12))),
                        Text(Fmt.money(inv.balance), style: t.heading),
                        const SizedBox(width: 4),
                        OlIcon(OlIcons.chevronRight, color: c.faint, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow(this.inv, {required this.divider, required this.onTap});
  final InvoiceV inv;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final st = inv.payState;
    final at = inv.paidAt ?? inv.issuedAt;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg, vertical: 14),
        decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: c.line)) : null),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: st == InvoicePayState.paid ? c.okSoft : c.surfaceAlt,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: OlIcon(
                inv.kind == 'package' ? OlIcons.package : OlIcons.receipt,
                size: 18,
                color: st == InvoicePayState.paid ? c.ok : c.faint,
              ),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_invoiceTitle(inv), style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    [if (at != null) Fmt.dayShort(at.toLocal()), ?inv.number].join(' · '),
                    style: t.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: OlSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Fmt.money(inv.total),
                  style: t.bodyStrong.copyWith(
                    decoration: st == InvoicePayState.voided ? TextDecoration.lineThrough : null,
                    color: st == InvoicePayState.voided ? c.faint : null,
                  ),
                ),
                const SizedBox(height: 2),
                OlTag(st.label, tone: _tone(st)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Isi lembar rincian tagihan: ringkasan + riwayat percobaan bayar.
class _InvoiceDetail extends StatelessWidget {
  const _InvoiceDetail(this.inv);
  final InvoiceV inv;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final st = inv.payState;
    final attempts = inv.payments.reversed.toList();
    Widget kv(String k, String v, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(k, style: t.body.copyWith(color: c.muted))),
          Text(v, style: style ?? t.bodyStrong),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .55),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (st.ended)
              Padding(
                padding: const EdgeInsets.only(bottom: OlSpace.md),
                child: OlBanner(
                  tone: OlBannerTone.crit,
                  message: 'Pembayaran terakhir ${st == InvoicePayState.failed ? 'gagal' : st.label.toLowerCase()} '
                      'dan tidak ada dana yang terpotong. Tagihan masih harus dibayar.',
                ),
              ),
            if (st == InvoicePayState.waiting)
              const Padding(
                padding: EdgeInsets.only(bottom: OlSpace.md),
                child: OlBanner(
                  tone: OlBannerTone.warn,
                  message: 'Kode pembayaran sudah terbit. Selesaikan pembayaran sebelum batas waktunya.',
                ),
              ),
            kv('Jenis', _invoiceTitle(inv)),
            kv('Status', st.label, style: t.bodyStrong.copyWith(color: switch (_tone(st)) {
              OlTagTone.ok => c.ok,
              OlTagTone.crit => c.crit,
              OlTagTone.warn => c.warn,
              _ => null,
            })),
            kv('Total', Fmt.money(inv.total)),
            if (inv.paid > 0) kv('Sudah dibayar', Fmt.money(inv.paid)),
            if (inv.balance > 0 && inv.payable) kv('Sisa tagihan', Fmt.money(inv.balance)),
            if (attempts.isNotEmpty) ...[
              const SizedBox(height: OlSpace.md),
              Text('RIWAYAT PEMBAYARAN', style: t.overline.copyWith(color: c.muted)),
              const SizedBox(height: 6),
              for (final p in attempts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_methodLabel(p), style: t.body),
                            if (p.createdAt != null)
                              Text(
                                '${_when(p.createdAt!)} · ${Fmt.money(p.amount)}',
                                style: t.caption.copyWith(color: c.muted),
                              ),
                          ],
                        ),
                      ),
                      OlTag(
                        paymentStatusLabels[p.status] ?? p.status,
                        tone: switch (p.status) {
                          'succeeded' => OlTagTone.ok,
                          'pending' || 'awaiting_verification' => OlTagTone.warn,
                          'failed' || 'rejected' || 'expired' => OlTagTone.crit,
                          _ => OlTagTone.muted,
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
