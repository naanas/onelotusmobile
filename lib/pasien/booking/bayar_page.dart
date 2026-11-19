import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';
import 'payment_channel_picker.dart';

/// PS-09 Pembayaran online (§6.4.2).
/// - Dari booking (`autostart`): metode sudah dipilih → tagihan langsung dibuat di gateway,
///   layar menampilkan instruksi sesuai metode (QR / nomor VA / tautan e-wallet) + nota tagihan.
/// - Dibuka tanpa metode: pilih kanal (logo + biaya admin Dupay) lalu geser untuk bayar.
/// Status lunas hanya dari callback gateway (webhook) — layar ini hanya memantau.
/// Kembali → daftar booking (Jadwal saya), bukan ke form booking.
class BayarPage extends ConsumerStatefulWidget {
  const BayarPage({
    super.key,
    this.invoiceId,
    this.initialMethod,
    this.initialBank,
    this.initialWallet,
    this.autoStart = false,
    this.prepare,
  });

  /// Booking yang sedang dibuat (dari geser bayar): selesai → id tagihan (null = tanpa tagihan).
  /// Selama berjalan layar menampilkan animasi; gagal → pesan error lalu kembali ke form booking.
  final Future<String?>? prepare;

  final String? invoiceId;
  final String? initialMethod;
  final String? initialBank;
  final String? initialWallet;
  final bool autoStart;

  @override
  ConsumerState<BayarPage> createState() => _BayarPageState();
}

class _BayarPageState extends ConsumerState<BayarPage> {
  String? _invoiceId;

  /// Null selama booking masih dibuat ([BayarPage.prepare]).
  Future<List<InvoiceV>>? _invoices;
  bool _noInvoice = false;

  /// Kanal terpilih (logo + biaya admin).
  PayChannelV? _channel;
  bool _feeBusy = false;
  PaymentV? _pending;
  bool _busy = false;
  bool _autoStarted = false;
  bool _restored = false;
  Timer? _poll;

  PasienAppApi get _api => ref.read(pasienAppApiProvider);

  @override
  void initState() {
    super.initState();
    _invoiceId = widget.invoiceId;
    final prep = widget.prepare;
    if (prep == null) {
      _invoices = _api.invoices();
    } else {
      prep.then(
        (id) {
          if (!mounted) return;
          setState(() {
            _invoiceId = id;
            _noInvoice = id == null;
            if (id != null) _invoices = _api.invoices();
          });
        },
        onError: (Object e) {
          if (!mounted) return;
          showApiError(context, e);
          context.pop(); // kembali ke form booking, isian masih utuh
        },
      );
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Booking tanpa tagihan online → ke daftar jadwal.
  void _back() => context.pushReplacement(PRoutes.jadwal);

  /// Dibuka dari alur booking (geser bayar), bukan dari Profil › Paket & pembayaran.
  bool get _fromBooking => widget.autoStart || widget.prepare != null;

  /// Tombol/gestur kembali: dari booking → Beranda; dari tempat lain → layar sebelumnya.
  /// Kode bayar sudah terbit → beri tahu pembayaran masih menunggu.
  void _leave() {
    final p = _pending;
    if (p != null) {
      final until = p.expiresAt == null
          ? ''
          : ' sebelum ${Fmt.dayShort(p.expiresAt!.toLocal())} ${Fmt.time(p.expiresAt!.toLocal())} WIB';
      context.feedback.info(
        'Pembayaran menunggu. Selesaikan pembayaran$until. '
        'Tagihan bisa dibuka lagi di Profil › Paket & pembayaran.',
      );
    }
    if (!_fromBooking && context.canPop()) {
      context.pop();
    } else {
      _home();
    }
  }

  /// Cocokkan metode ke kanal Dupay (logo + biaya admin).
  Future<void> _resolveChannel(int amount, String? m, {String? bank, String? wallet}) async {
    if (m == null) return;
    try {
      final list = await _api.paymentChannels(amount);
      final ch = list.where((c) {
        if (c.method != m) return false;
        if (m == 'va') return c.vaBank == bank;
        if (m == 'ewallet') return wallet == null || c.ewallet == wallet;
        return true;
      }).firstOrNull;
      if (mounted && ch != null) setState(() => _channel = ch);
    } catch (_) {}
  }

  Future<void> _pay(
    InvoiceV inv, {
    String? method,
    String? bank,
    String? wallet,
  }) async {
    setState(() => _busy = true);
    final r = await runApi(
      context,
      () => _api.pay(
        inv.id,
        method: method ?? _channel!.method,
        vaBank: bank ?? _channel?.vaBank,
        ewallet: wallet ?? _channel?.ewallet,
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

  /// Pantau hasil dari Dupay/PG (callback diproses server): lunas → struk; gagal/kedaluwarsa/dibatalkan →
  /// instruksi ditutup, status gagal ditampilkan, pasien bisa memilih metode lagi.
  void _watch(String id) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final all = await _api.invoices();
        final inv = all.where((i) => i.id == id).firstOrNull;
        if (!mounted || inv == null) return;
        if (inv.status == 'paid') return _done(inv);
        final mine = _pending == null ? null : inv.payments.where((p) => p.id == _pending!.id).firstOrNull;
        if (mine != null && !mine.pending) {
          _poll?.cancel();
          setState(() {
            _pending = null;
            _invoices = Future.value(all);
          });
          HapticFeedback.heavyImpact();
          context.feedback.info(
            'Pembayaran ${_methodName(mine)} ${paymentStatusLabels[mine.status]?.toLowerCase() ?? mine.status}. '
            'Tidak ada dana yang terpotong — silakan coba lagi.',
          );
        }
      } catch (_) {}
    });
  }

  static String _methodName(PaymentV p) =>
      p.method == 'va' && p.vaBank != null ? '${p.vaBank!.toUpperCase()} VA' : paymentMethodLabels[p.method] ?? p.method;

  void _done(InvoiceV inv) {
    _poll?.cancel();
    context.feedback.success('Pembayaran diterima. Terima kasih.');
    if (inv.receiptId != null) {
      // Struk dari pembayaran: tombol "Selesai" → Beranda.
      context.pushReplacement('${PRoutes.struk}?id=${inv.receiptId}&done=1');
    } else {
      _home();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop || _loadingPhase) return; // proses berjalan: jangan diputus
      _leave();
    },
    child: _noInvoice
        ? _scaffold(
            children: [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptySchedule,
                  title: 'Jadwal tercatat',
                  message:
                      'Booking Anda sudah terdaftar dan tidak memerlukan pembayaran online.',
                  actionLabel: 'Lihat jadwal',
                  onAction: _back,
                ),
              ),
            ],
          )
        : _invoices == null
        ? _loading(
            title: 'Memproses booking Anda',
            message: 'Kami sedang mengamankan jadwal terapi Anda. Mohon tidak menutup halaman ini.',
          )
        : FutureBuilder<List<InvoiceV>>(
            future: _invoices,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return _loading(
                  title: 'Memuat rincian tagihan',
                  message: 'Mohon tunggu sebentar.',
                );
              }
              if (snap.hasError) {
                return _scaffold(
                  children: [
                    OlCard(
                      child: EmptyState(
                        illustration: OlIllustration.emptyInbox,
                        title: 'Tagihan gagal dimuat',
                        message: 'Periksa koneksi lalu coba lagi.',
                        actionLabel: 'Coba lagi',
                        onAction: () =>
                            setState(() {
                              _invoices = _api.invoices();
                            }),
                      ),
                    ),
                  ],
                );
              }
              return _body(context, snap.data!);
            },
          ),
  );

  /// Diperbarui tiap build: true selama booking/tagihan sedang diproses (tombol kembali disembunyikan).
  bool _loadingPhase = false;

  Widget _scaffold({
    required List<Widget> children,
    List<Widget> foot = const [],
    bool showBack = true,
  }) {
    _loadingPhase = false;
    return OlDetailScaffold(
      pinnedHeader: true,
      title: 'Pembayaran',
      showBack: showBack,
      onBack: _leave,
      foot: foot,
      children: children,
    );
  }

  /// Layar memuat: hanya animasi + status di tengah (tanpa judul & tombol kembali —
  /// proses tidak boleh diputus di tengah jalan).
  Widget _loading({required String title, required String message}) {
    _loadingPhase = true;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OlStatusBar.dark,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: OlSpace.screen * 1.5),
              child: _LottieStatus(
                asset: 'assets/lottie/an_payment_processing.json',
                title: title,
                message: message,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ke Beranda (status lunas tetap dipantau server lewat callback).
  void _home() => context.go(PRoutes.beranda);

  Widget _body(BuildContext context, List<InvoiceV> all) {
    final t = context.olText;
    final open = [
      for (final i in all)
        if (i.payable && i.status != 'draft') i,
    ];
    final inv =
        open.where((i) => i.id == _invoiceId).firstOrNull ??
        (open.length == 1 ? open.first : null);
    if (open.isEmpty) {
      return _scaffold(
        children: const [
          OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptyInbox,
              title: 'Tidak ada tagihan',
              message: 'Semua tagihan Anda sudah lunas.',
            ),
          ),
        ],
      );
    }
    if (inv == null) {
      return _scaffold(
        children: [
          const OlSectionHeader(title: 'Pilih tagihan'),
          for (final i in open)
            OlCard(
              onTap: () => setState(() => _invoiceId = i.id),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        i.number ?? 'Tagihan',
                        if (i.sessionDate != null) Fmt.dayShort(i.sessionDate!),
                      ].join(' · '),
                      style: t.bodyStrong,
                    ),
                  ),
                  Text(Fmt.money(i.balance), style: t.bodyStrong),
                ],
              ),
            ),
        ],
      );
    }

    // Dari booking: metode sudah dipilih → langsung buat tagihan di gateway.
    final m = widget.initialMethod;
    if (widget.autoStart &&
        m != null &&
        !_autoStarted &&
        _pending == null &&
        !_busy) {
      _autoStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resolveChannel(inv.balance, m, bank: widget.initialBank, wallet: widget.initialWallet);
        _pay(
          inv,
          method: m,
          bank: widget.initialBank,
          wallet: widget.initialWallet,
        );
      });
    }

    // Kode bayar sudah terbit sebelumnya (mis. dibuka dari Profil) → tampilkan lagi, jangan buat baru.
    final existing = inv.pendingPayment;
    if (!_autoStarted &&
        !_restored &&
        _pending == null &&
        !_busy &&
        existing != null &&
        (existing.expiresAt == null || existing.expiresAt!.isAfter(DateTime.now()))) {
      _restored = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _pending = existing);
        _resolveChannel(inv.balance, existing.method, bank: existing.vaBank);
        _watch(inv.id);
      });
    }

    final fee = _channel?.fee ?? 0;
    final p = _pending;

    if (_busy && p == null) {
      return _loading(
        title: 'Menyiapkan instruksi pembayaran',
        message: _channel == null
            ? 'Kode pembayaran Anda sedang diterbitkan. Proses ini hanya memerlukan beberapa detik.'
            : 'Kode pembayaran ${_channel!.label} sedang diterbitkan. Proses ini hanya memerlukan beberapa detik.',
      );
    }

    if (p != null) {
      return _scaffold(
        children: [
          _PaymentInstruction(payment: p, channel: _channel),
          // QRIS sudah punya status + hitung mundur di panelnya sendiri.
          if (p.qrString == null) const _WaitingRow(),
          PaperReceipt(invoice: inv, fee: fee, feeLabel: _channel?.label),
        ],
      );
    }

    // Tanpa metode (dibuka dari tempat lain) atau gagal membuat tagihan: pilih kanal → geser.
    return _scaffold(
      foot: [
        OlSlideToConfirm(
          label: 'Geser untuk bayar ${Fmt.money(inv.balance + fee)}',
          loading: _busy,
          onConfirmed: _channel == null || _feeBusy ? null : () => _pay(inv),
        ),
      ],
      children: [
        if (inv.payState.ended && inv.lastAttempt != null)
          OlBanner(
            tone: OlBannerTone.crit,
            message: 'Pembayaran ${_methodName(inv.lastAttempt!)} sebelumnya '
                '${inv.payState == InvoicePayState.failed ? 'gagal' : inv.payState.label.toLowerCase()}. '
                'Tidak ada dana yang terpotong. Pilih metode untuk membayar lagi.',
          ),
        PaperReceipt(invoice: inv, fee: fee, feeLabel: _channel?.label),
        const OlSectionHeader(title: 'Metode pembayaran'),
        PaymentChannelPicker(
          amount: inv.balance,
          value: _channel,
          onBusy: (v) => setState(() => _feeBusy = v),
          onChanged: (ch) => setState(() => _channel = ch),
        ),
      ],
    );
  }
}

/// Instruksi bayar sesuai metode yang dipilih: QR, nomor VA, atau tautan e-wallet.
class _PaymentInstruction extends StatelessWidget {
  const _PaymentInstruction({required this.payment, required this.channel});
  final PaymentV payment;
  final PayChannelV? channel;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final p = payment;
    final ch = channel;
    final deadline = p.expiresAt == null
        ? null
        : 'Bayar sebelum ${Fmt.dayShort(p.expiresAt!.toLocal())} · ${Fmt.time(p.expiresAt!.toLocal())} WIB';

    Widget header(String title) => Row(
      children: [
        if (ch != null) ...[
          PayChannelLogo(channel: ch),
          const SizedBox(width: OlSpace.md),
        ],
        Expanded(child: Text(title, style: t.heading)),
      ],
    );

    if (p.qrString != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QrisPanel(
            data: p.qrString,
            expiresIn:
                p.expiresAt?.difference(DateTime.now()) ??
                const Duration(minutes: 15),
          ),
        ],
      );
    }

    if (p.vaNumber != null) {
      return OlCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(
              ch?.label ?? 'Virtual Account ${(p.vaBank ?? '').toUpperCase()}',
            ),
            const SizedBox(height: OlSpace.lg),
            Text(
              'Nomor Virtual Account',
              style: t.caption.copyWith(color: c.muted),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _groupDigits(p.vaNumber!),
                    style: t.mono.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                OlIconButton(
                  icon: OlIcons.copy,
                  semanticLabel: 'Salin nomor',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: p.vaNumber!));
                    context.feedback.success('Nomor VA disalin.');
                  },
                ),
              ],
            ),
            if (deadline != null)
              Text(deadline, style: t.caption.copyWith(color: c.warn)),
            const SizedBox(height: OlSpace.md),
            Text(
              'Transfer lewat m-banking, ATM, atau internet banking ke nomor di atas. '
              'Nominal harus sama persis dengan total tagihan.',
              style: t.caption.copyWith(color: c.muted),
            ),
          ],
        ),
      );
    }

    if (p.paymentUrl != null) {
      return OlCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(ch?.label ?? 'E-Wallet'),
            const SizedBox(height: OlSpace.md),
            Text(
              'Selesaikan pembayaran di aplikasi ${ch?.label ?? 'e-wallet'} melalui tautan berikut.',
              style: t.body,
            ),
            const SizedBox(height: OlSpace.sm),
            SelectableText(
              p.paymentUrl!,
              maxLines: 2,
              style: t.caption.copyWith(color: c.brand),
            ),
            if (deadline != null) ...[
              const SizedBox(height: 4),
              Text(deadline, style: t.caption.copyWith(color: c.warn)),
            ],
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
      );
    }

    return OlCard(
      child: Text(
        'Tagihan pembayaran telah diterbitkan. Status akan diperbarui otomatis setelah pembayaran diterima.',
        style: t.body,
      ),
    );
  }

  static String _groupDigits(String s) =>
      s.replaceAllMapped(RegExp(r'(\d{4})(?=\d)'), (m) => '${m[1]} ');
}

/// Animasi Lottie + teks status (pengganti skeleton saat menyiapkan/menunggu pembayaran).
class _LottieStatus extends StatelessWidget {
  const _LottieStatus({
    required this.asset,
    required this.title,
    required this.message,
  });

  final String asset, title, message;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final reduced = OlMotion.reduced(context);
    final anim = SizedBox.square(
      dimension: 220,
      child: Lottie.asset(asset, animate: !reduced, frameRate: FrameRate.max),
    );
    return Semantics(
      liveRegion: true,
      label: '$title. $message',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          anim,
          const SizedBox(height: OlSpace.lg),
          Text(title, style: t.heading, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            message,
            style: t.body.copyWith(color: c.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Nota tagihan bergaya kertas struk: tepi bergerigi, garis putus-putus, huruf mono.
class PaperReceipt extends StatelessWidget {
  const PaperReceipt({
    super.key,
    required this.invoice,
    this.fee = 0,
    this.feeLabel,
  });
  final InvoiceV invoice;
  final int fee;
  final String? feeLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final i = invoice;
    final mono = t.mono.copyWith(fontSize: 13, color: c.fg);
    final monoMuted = mono.copyWith(color: c.muted);

    Widget row(
      String label,
      int amount, {
      bool discount = false,
      TextStyle? style,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style ?? mono)),
          const SizedBox(width: OlSpace.sm),
          Text(
            '${discount ? '−' : ''}${Fmt.money(amount)}',
            style: style ?? mono,
          ),
        ],
      ),
    );

    final discounts = [
      if (i.memberDiscount > 0) ('Harga member', i.memberDiscount),
      if (i.voucherDiscount > 0)
        ('Voucher ${i.voucherCode ?? ''}'.trim(), i.voucherDiscount),
      if (i.manualDiscount > 0) ('Diskon', i.manualDiscount),
      if (i.pointsDiscount > 0)
        ('Poin Lotus (${i.pointsUsed})', i.pointsDiscount),
    ];

    return PhysicalShape(
      clipper: const _ZigzagClipper(),
      color: const Color(0xFFFFFEFA),
      elevation: 2,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(OlSpace.xl, 26, OlSpace.xl, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ONE LOTUS',
              textAlign: TextAlign.center,
              style: mono.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            Text(
              'Personal Therapy',
              textAlign: TextAlign.center,
              style: monoMuted.copyWith(fontSize: 11.5),
            ),
            const SizedBox(height: OlSpace.md),
            const _Dashed(),
            const SizedBox(height: OlSpace.sm),
            _kv('No. tagihan', i.number ?? '-', mono, monoMuted),
            _kv(
              'Pasien',
              '${i.patientName} ${Fmt.patientNo(i.patientNumber)}',
              mono,
              monoMuted,
            ),
            if (i.sessionDate != null)
              _kv(
                'Jadwal',
                '${Fmt.dayShort(i.sessionDate!.toLocal())} ${Fmt.time(i.sessionDate!.toLocal())}',
                mono,
                monoMuted,
              ),
            if (i.therapistName != null)
              _kv('Terapis', i.therapistName!, mono, monoMuted),
            const SizedBox(height: OlSpace.sm),
            const _Dashed(),
            const SizedBox(height: OlSpace.sm),
            for (final it in i.items)
              row(
                it.qty > 1 ? '${it.qty}× ${it.description}' : it.description,
                it.amount,
              ),
            if (discounts.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final (label, amount) in discounts)
                row(
                  label,
                  amount,
                  discount: true,
                  style: mono.copyWith(color: c.ok),
                ),
            ],
            if (i.paid > 0)
              row('Sudah dibayar', i.paid, discount: true, style: monoMuted),
            row(
              feeLabel == null ? 'Biaya admin' : 'Biaya admin ($feeLabel)',
              fee,
              style: monoMuted,
            ),
            const SizedBox(height: OlSpace.sm),
            const _Dashed(),
            const SizedBox(height: OlSpace.sm),
            row(
              'TOTAL BAYAR',
              i.balance + fee,
              style: mono.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: OlSpace.md),
            Text(
              '— terima kasih —',
              textAlign: TextAlign.center,
              style: monoMuted.copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v, TextStyle mono, TextStyle muted) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 96, child: Text(k, style: muted)),
            Expanded(
              child: Text(v, style: mono, textAlign: TextAlign.right),
            ),
          ],
        ),
      );
}

/// Garis putus-putus selebar penuh.
class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: CustomPaint(painter: _DashPainter(context.ol.line)),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + 5, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Tepi atas & bawah bergerigi seperti sobekan kertas struk.
class _ZigzagClipper extends CustomClipper<Path> {
  const _ZigzagClipper();

  @override
  Path getClip(Size size) {
    const tooth = 12.0, depth = 7.0;
    final n = (size.width / tooth).ceil();
    final w = size.width / n;
    final path = Path()..moveTo(0, depth);
    for (var i = 0; i < n; i++) {
      path.lineTo(w * i + w / 2, 0);
      path.lineTo(w * (i + 1), depth);
    }
    path.lineTo(size.width, size.height - depth);
    for (var i = n; i > 0; i--) {
      path.lineTo(w * i - w / 2, size.height);
      path.lineTo(w * (i - 1), size.height - depth);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_ZigzagClipper old) => false;
}

/// Status menunggu (VA / e-wallet): titik berdenyut + teks.
class _WaitingRow extends StatefulWidget {
  const _WaitingRow();

  @override
  State<_WaitingRow> createState() => _WaitingRowState();
}

class _WaitingRowState extends State<_WaitingRow> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OlMotion.reduced(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg, vertical: OlSpace.md),
      decoration: BoxDecoration(
        color: c.warnSoft,
        borderRadius: BorderRadius.circular(OlRadius.banner),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: Tween(begin: .35, end: 1.0).animate(_pulse),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c.warn, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: OlSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Menunggu pembayaran', style: t.bodyStrong),
                Text(
                  'Layar ini berganti otomatis setelah pembayaran diterima.',
                  style: t.caption.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
