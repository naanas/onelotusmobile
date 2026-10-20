import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

const _banks = {'bca': 'BCA', 'bni': 'BNI', 'bri': 'BRI', 'mandiri': 'Mandiri', 'permata': 'Permata'};
const _wallets = {'ovo': 'OVO', 'dana': 'DANA', 'shopeepay': 'ShopeePay'};

/// PS-09 Pembayaran online (§6.4.2): tagihan belum lunas → pilih metode gateway.
/// Status lunas hanya dari konfirmasi sistem (webhook) — layar ini hanya memantau.
class BayarPage extends ConsumerStatefulWidget {
  const BayarPage({super.key, this.invoiceId});
  final String? invoiceId;

  @override
  ConsumerState<BayarPage> createState() => _BayarPageState();
}

class _BayarPageState extends ConsumerState<BayarPage> {
  String? _invoiceId;
  String _method = 'qris';
  String _bank = 'bca';
  String _wallet = 'ovo';
  PaymentV? _pending;
  bool _busy = false;
  Timer? _poll;
  int _gen = 0;

  PasienAppApi get _api => ref.read(pasienAppApiProvider);

  @override
  void initState() {
    super.initState();
    _invoiceId = widget.invoiceId;
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pay(InvoiceV inv) async {
    setState(() => _busy = true);
    final r = await runApi(
      context,
      () => _api.pay(
        inv.id,
        method: _method,
        vaBank: _method == 'va' ? _bank : null,
        ewallet: _method == 'ewallet' ? _wallet : null,
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pending = r?.payment;
    });
    if (r == null) return;
    if (r.invoice.status == 'paid') return _done(r.invoice);
    _watch(inv.id);
  }

  void _watch(String id) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final inv = (await _api.invoices()).where((i) => i.id == id).firstOrNull;
        if (!mounted || inv == null) return;
        if (inv.status == 'paid') _done(inv);
      } catch (_) {}
    });
  }

  void _done(InvoiceV inv) {
    _poll?.cancel();
    context.feedback.success('Pembayaran diterima. Terima kasih.');
    if (inv.receiptId != null) {
      context.pushReplacement('${PRoutes.struk}?id=${inv.receiptId}');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Pembayaran',
    children: [
      OlAsync<List<InvoiceV>>(
        key: ValueKey(_gen),
        load: _api.invoices,
        builder: (context, all, _) {
          final c = context.ol;
          final t = context.olText;
          final open = [for (final i in all) if (i.payable && i.status != 'draft') i];
          final inv = open.where((i) => i.id == _invoiceId).firstOrNull ?? (open.length == 1 ? open.first : null);
          if (open.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Tidak ada tagihan', message: 'Semua tagihan Anda sudah lunas.'))];
          }
          if (inv == null) {
            return [
              const OlSectionHeader(title: 'Pilih tagihan'),
              for (final i in open)
                OlCard(
                  onTap: () => setState(() => _invoiceId = i.id),
                  child: Row(
                    children: [
                      Expanded(child: Text([i.number ?? 'Tagihan', if (i.sessionDate != null) Fmt.dayShort(i.sessionDate!)].join(' · '), style: t.bodyStrong)),
                      Text(Fmt.money(i.balance), style: t.bodyStrong),
                    ],
                  ),
                ),
            ];
          }
          final p = _pending;
          return [
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InvoiceBreakdown(invoice: inv),
                ],
              ),
            ),
            if (p == null) ...[
              const OlSectionHeader(title: 'Metode pembayaran'),
              OlSegmented<String>(
                segments: const {'qris': 'QRIS', 'va': 'Virtual account', 'ewallet': 'E-wallet'},
                value: _method,
                onChanged: (v) => setState(() => _method = v),
              ),
              if (_method == 'va')
                Wrap(
                  spacing: OlSpace.sm,
                  runSpacing: OlSpace.sm,
                  children: [for (final MapEntry(:key, :value) in _banks.entries) OlChip(label: value, small: true, selected: _bank == key, onTap: () => setState(() => _bank = key))],
                ),
              if (_method == 'ewallet')
                Wrap(
                  spacing: OlSpace.sm,
                  children: [for (final MapEntry(:key, :value) in _wallets.entries) OlChip(label: value, small: true, selected: _wallet == key, onTap: () => setState(() => _wallet = key))],
                ),
              OlButton(label: 'Bayar ${Fmt.money(inv.balance)}', loading: _busy, onPressed: () => _pay(inv)),
            ] else ...[
              if (p.qrString != null)
                QrisPanel(
                  data: p.qrString,
                  expiresIn: p.expiresAt?.difference(DateTime.now()) ?? const Duration(minutes: 15),
                  onExpired: () => setState(() {
                    _pending = null;
                    _poll?.cancel();
                  }),
                ),
              if (p.vaNumber != null)
                OlCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Nomor virtual account ${_banks[p.vaBank] ?? p.vaBank ?? ''}', style: t.caption.copyWith(color: c.muted)),
                      Text(p.vaNumber!, style: t.mono.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
                      if (p.expiresAt != null) Text('Bayar sebelum ${Fmt.dayShort(p.expiresAt!)} ${Fmt.time(p.expiresAt!)}', style: t.caption.copyWith(color: c.muted)),
                      const SizedBox(height: OlSpace.md),
                      OlButton.secondary(
                        label: 'Salin nomor',
                        icon: OlIcons.copy,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: p.vaNumber!));
                          context.feedback.success('Nomor disalin.');
                        },
                      ),
                    ],
                  ),
                ),
              if (p.paymentUrl != null && p.qrString == null && p.vaNumber == null)
                OlCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Lanjutkan pembayaran di aplikasi ${_wallets[_wallet] ?? 'e-wallet'} melalui tautan berikut.', style: t.body),
                      const SizedBox(height: OlSpace.md),
                      OlButton.secondary(
                        label: 'Salin tautan pembayaran',
                        icon: OlIcons.copy,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: p.paymentUrl!));
                          context.feedback.success('Tautan disalin. Buka di browser.');
                        },
                      ),
                    ],
                  ),
                ),
              OlBanner(message: 'Menunggu konfirmasi pembayaran. Layar ini berganti otomatis setelah lunas.', tone: OlBannerTone.info),
              OlButton.text(
                label: 'Ganti metode',
                onPressed: () => setState(() {
                  _pending = null;
                  _poll?.cancel();
                  _gen++;
                }),
                expand: true,
              ),
            ],
          ];
        },
      ),
    ],
  );
}
