import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'billing_common.dart';

enum PayMethod { cash, qris, transfer, package, points, link }

/// KS-10 Pembayaran (dan TR-10 tagih di lokasi bila [homeVisit]): Tunai (KS-10a), QRIS (KS-10b), Transfer,
/// Paket → gabungan (KS-10c), Poin, Link bayar. Lunas hanya ditetapkan server; QRIS dipantau tiap 5 detik.
class BayarPage extends ConsumerStatefulWidget {
  const BayarPage({super.key, required this.invoiceId, this.homeVisit = false});

  final String invoiceId;
  final bool homeVisit;

  @override
  ConsumerState<BayarPage> createState() => _BayarPageState();
}

class _BayarPageState extends ConsumerState<BayarPage> {
  BillingApi get _api => ref.read(billingApiProvider);

  InvoiceV? _inv;
  List<OwnershipV> _packages = const [];
  Object? _error;
  PayMethod _method = PayMethod.cash;
  bool _busy = false;

  int _received = 0;
  final _bank = TextEditingController();
  final _points = TextEditingController();
  String? _proofId;
  String? _ownership;

  PaymentV? _pending; // QRIS / link yang sedang menunggu
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _bank.dispose();
    _points.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final inv = await _api.invoice(widget.invoiceId);
      final pk = inv.patientId == null ? <OwnershipV>[] : await _api.patientPackages(inv.patientId!);
      if (!mounted) return;
      setState(() {
        _inv = inv;
        _packages = [for (final p in pk) if (p.status == 'active' && p.remaining > 0) p];
        _ownership ??= _packages.firstOrNull?.id;
        _received = inv.balance;
        _error = null;
        final pending = inv.pendingPayment;
        if (pending != null && (pending.method == 'qris' || pending.method == 'payment_link')) {
          _pending = pending;
          _method = pending.method == 'qris' ? PayMethod.qris : PayMethod.link;
          _startPoll();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      final p = _pending;
      if (p == null) return;
      try {
        final r = await _api.payment(p.id);
        if (!mounted) return;
        if (r.payment.status == 'succeeded') {
          _poll?.cancel();
          _done(r);
        } else if (!r.payment.pending) {
          _poll?.cancel();
          setState(() => _pending = null);
          context.feedback.info(r.payment.status == 'expired' ? 'Kode QR kedaluwarsa. Buat QR baru.' : 'Pembayaran belum berhasil.');
        }
      } catch (_) {
        // Sinyal putus: coba lagi di putaran berikut.
      }
    });
  }

  void _done(PaymentResult r) {
    HapticFeedback.mediumImpact();
    if (r.receipt != null) {
      context.pushReplacement(Routes.struk(r.receipt!.id));
      return;
    }
    if (r.payment.status == 'awaiting_verification') {
      context.feedback.success('Bukti transfer terkirim. Menunggu verifikasi kasir lain.');
      context.pop();
      return;
    }
    context.feedback.success('${paymentMethodLabels[r.payment.method]} ${Fmt.money(r.payment.amount)} tercatat. Sisa ${Fmt.money(r.invoice.balance)}.');
    setState(() {
      _inv = r.invoice;
      _received = r.invoice.balance;
      _packages = [for (final p in _packages) if (p.id != r.payment.id) p];
    });
    unawaited(_load());
  }

  String get _location => widget.homeVisit ? 'home_visit' : 'clinic';

  Future<void> _submit() async {
    final inv = _inv!;
    final body = <String, dynamic>{'collected_at_location': _location, 'id': null};
    switch (_method) {
      case PayMethod.cash:
        if (_received < 1) return context.feedback.info('Isi uang yang diterima.');
        body.addAll({'method': 'cash', 'amount': _received < inv.balance ? _received : inv.balance, 'cash_received': _received});
      case PayMethod.qris:
        body.addAll({'method': 'qris', 'amount': inv.balance});
      case PayMethod.transfer:
        if (_bank.text.trim().isEmpty) return context.feedback.info('Isi nama bank pengirim.');
        if (_proofId == null) return context.feedback.info('Unggah bukti transfer.');
        body.addAll({'method': 'transfer_manual', 'amount': inv.balance, 'bank_name': _bank.text.trim(), 'proof_attachment_id': _proofId});
      case PayMethod.package:
        if (_ownership == null) return context.feedback.info('Pilih paket.');
        body.addAll({'method': 'package', 'amount': inv.balance, 'package_ownership_id': _ownership});
      case PayMethod.points:
        final pts = parseAmount(_points.text);
        if (pts < 1) return context.feedback.info('Isi jumlah poin.');
        body.addAll({'method': 'points', 'amount': inv.balance, 'points': pts});
      case PayMethod.link:
        setState(() => _busy = true);
        final y = await runApi(context, () => _api.paymentLink(inv.id));
        if (!mounted) return;
        setState(() {
          _busy = false;
          if (y != null) _pending = y;
        });
        if (y != null) {
          context.feedback.success('Link bayar dikirim ke WhatsApp pasien.');
          _startPoll();
        }
        return;
    }
    body.remove('id');
    setState(() => _busy = true);
    final r = await runApi(context, () => _api.pay(inv.id, body));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) return;
    if (r.payment.status == 'pending') {
      setState(() => _pending = r.payment);
      _startPoll();
      return;
    }
    _done(r);
  }

  Future<void> _newQr() async {
    final p = _pending;
    if (p != null) {
      setState(() => _busy = true);
      await runApi(context, () => _api.cancelPayment(p.id));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pending = null;
      });
    }
    await _submit();
  }

  Future<void> _pickProof() async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
    if (img == null || !mounted) return;
    setState(() => _busy = true);
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    final id = await runApi(
      context,
      () => _api.upload(ownerType: 'payment', ownerId: widget.invoiceId, kind: 'transfer_proof', mime: 'image/jpeg', bytes: bytes),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (id != null) _proofId = id;
    });
  }

  Map<PayMethod, String> get _methods => {
    PayMethod.cash: 'Tunai',
    PayMethod.qris: 'QRIS',
    if (!widget.homeVisit) PayMethod.transfer: 'Transfer',
    if (_packages.isNotEmpty) PayMethod.package: 'Paket',
    PayMethod.points: 'Poin',
    PayMethod.link: 'Link bayar',
  };

  @override
  Widget build(BuildContext context) {
    final inv = _inv;
    final title = widget.homeVisit ? 'Tagih di lokasi' : 'Pembayaran';
    if (inv == null) {
      return OlDetailScaffold(
        title: title,
        children: [
          if (_error != null)
            OlErrorCard(
              message: _error is AppError ? (_error as AppError).message : 'Tagihan belum bisa dimuat.',
              onRetry: _load,
            )
          else
            const OlLoadingCard(),
        ],
      );
    }
    final c = context.ol;
    final t = context.olText;
    final waiting = _pending != null;
    return OlDetailScaffold(
      title: title,
      context_: '${inv.patientName} · ${Fmt.patientNo(inv.patientNumber)}',
      foot: [
        if (!waiting && inv.balance > 0)
          OlButton(
            label: switch (_method) {
              PayMethod.qris => 'Tampilkan QR ${Fmt.money(inv.balance)}',
              PayMethod.link => 'Kirim link bayar',
              _ => 'Konfirmasi pembayaran',
            },
            loading: _busy,
            onPressed: _submit,
          ),
        if (waiting && _method == PayMethod.qris) ...[
          OlButton.secondary(label: 'Buat QR baru', loading: _busy, onPressed: _newQr),
        ],
      ],
      children: [
        OlCard(
          child: Column(
            children: [
              Text('Sisa tagihan', style: t.caption.copyWith(color: c.muted)),
              const SizedBox(height: 4),
              Text(Fmt.money(inv.balance), style: t.display),
              if (inv.paid > 0) Text('Sudah dibayar ${Fmt.money(inv.paid)}', style: t.caption.copyWith(color: c.muted)),
            ],
          ),
        ),
        if (inv.balance == 0)
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tagihan sudah lunas.', style: t.bodyStrong),
                if (inv.receiptId != null) ...[
                  const SizedBox(height: OlSpace.md),
                  OlButton(label: 'Lihat struk', onPressed: () => context.pushReplacement(Routes.struk(inv.receiptId!))),
                ],
              ],
            ),
          )
        else ...[
          if (!waiting)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final m in _methods.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: OlSpace.sm),
                      child: OlChip(label: m.value, selected: _method == m.key, onTap: () => setState(() => _method = m.key)),
                    ),
                ],
              ),
            ),
          _panel(context, inv),
        ],
      ],
    );
  }

  Widget _panel(BuildContext context, InvoiceV inv) {
    final c = context.ol;
    final t = context.olText;
    switch (_method) {
      case PayMethod.cash:
        final change = _received - inv.balance;
        final quick = <int>{
          inv.balance,
          ((inv.balance + 49999) ~/ 50000) * 50000,
          ((inv.balance + 99999) ~/ 100000) * 100000,
        }.where((v) => v > 0).toList()
          ..sort();
        return OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OlMoneyField(label: 'Uang diterima', value: _received, onChanged: (v) => setState(() => _received = v)),
              const SizedBox(height: OlSpace.sm),
              Wrap(
                spacing: OlSpace.sm,
                children: [
                  for (final v in quick)
                    OlChip(label: v == inv.balance ? 'Pas' : Fmt.money(v), small: true, selected: _received == v, onTap: () => setState(() => _received = v)),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              OlMoneyRow(label: 'Total tagihan', amount: inv.balance),
              if (change >= 0)
                OlMoneyRow(label: 'Kembalian', amount: change)
              else
                OlMoneyRow(label: 'Sisa setelah dibayar', amount: -change),
              const SizedBox(height: OlSpace.sm),
              Text(
                widget.homeVisit ? 'Uang tunai dicatat sebagai kas dibawa dan diserahkan ke kasir.' : 'Tunai tercatat atas namamu sebagai penerima.',
                style: t.caption.copyWith(color: c.muted),
              ),
            ],
          ),
        );
      case PayMethod.qris:
        final p = _pending;
        if (p == null) {
          return OlCard(child: Text('QR berlaku 15 menit. Pasien memindai dengan aplikasi bank / e-wallet.', style: t.body.copyWith(color: c.muted)));
        }
        return OlCard(
          child: Column(
            children: [
              Text('Scan dengan aplikasi bank / e-wallet', style: t.bodyStrong),
              const SizedBox(height: OlSpace.md),
              QrisPanel(
                key: ValueKey(p.id),
                data: p.qrString ?? p.paymentUrl ?? p.id,
                expiresIn: (p.expiresAt ?? DateTime.now().add(const Duration(minutes: 15))).difference(DateTime.now()),
                onExpired: () => setState(() {}),
              ),
              const SizedBox(height: OlSpace.md),
              Text('Layar berubah otomatis setelah pembayaran diterima. Jangan tagih ulang selama status masih menunggu.',
                  textAlign: TextAlign.center, style: t.caption.copyWith(color: c.muted)),
            ],
          ),
        );
      case PayMethod.transfer:
        return OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OlTextField(label: 'Bank pengirim', controller: _bank, isRequired: true),
              const SizedBox(height: OlSpace.md),
              OlButton.secondary(
                label: _proofId == null ? 'Foto bukti transfer' : 'Bukti terunggah · ganti',
                icon: _proofId == null ? OlIcons.camera : OlIcons.checkCircle,
                loading: _busy,
                onPressed: _pickProof,
              ),
              const SizedBox(height: OlSpace.sm),
              Text('Transfer diverifikasi kasir/owner lain sebelum lunas.', style: t.caption.copyWith(color: c.muted)),
            ],
          ),
        );
      case PayMethod.package:
        return OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (n, p) in _packages.indexed)
                OlListItem(
                  title: p.name,
                  subtitle: 'Sisa ${p.remaining} dari ${p.total} sesi${p.expiresOn == null ? '' : ' · s.d. ${Fmt.dateNoDay(p.expiresOn!)}'}',
                  trailing: _ownership == p.id ? OlIcon(OlIcons.checkCircle, color: c.brand) : null,
                  divider: n < _packages.length - 1,
                  onTap: () => setState(() => _ownership = p.id),
                ),
            ],
          ),
        );
      case PayMethod.points:
        return OlCard(
          child: OlTextField(label: 'Jumlah poin', controller: _points, keyboardType: TextInputType.number, helper: 'Nilai poin diatur owner.'),
        );
      case PayMethod.link:
        final p = _pending;
        return OlCard(
          child: Text(
            p == null
                ? 'Link bayar (QRIS/VA/e-wallet) dikirim ke WhatsApp pasien. Status lunas diperbarui otomatis.'
                : 'Link terkirim. Menunggu pasien membayar…\n${p.paymentUrl ?? ''}',
            style: t.body.copyWith(color: c.muted),
          ),
        );
    }
  }
}
