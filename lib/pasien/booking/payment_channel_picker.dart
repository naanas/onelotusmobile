import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/format.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Pilih kanal bayar online (PS-08/PS-09): dikelompokkan QRIS / Virtual Account / E-Wallet,
/// dengan logo & biaya admin dari Dupay. Setiap ketukan menghitung ulang biaya di server
/// (`GET /v1/patient/payment-channels?code=`), lalu [onChanged] dengan kanal ber-biaya terbaru.
/// [onBusy] = sedang menghitung biaya (total di layar sebaiknya ditandai memuat).
class PaymentChannelPicker extends ConsumerStatefulWidget {
  const PaymentChannelPicker({
    super.key,
    required this.amount,
    required this.value,
    required this.onChanged,
    this.onBusy,
  });

  final int amount;
  final PayChannelV? value;
  final ValueChanged<PayChannelV> onChanged;
  final ValueChanged<bool>? onBusy;

  @override
  ConsumerState<PaymentChannelPicker> createState() => _PaymentChannelPickerState();
}

class _PaymentChannelPickerState extends ConsumerState<PaymentChannelPicker> {
  late Future<List<PayChannelV>> _future = _load();
  String? _loadingCode;

  /// Server lama tanpa `/v1/patient/payment-channels` (404): pilihan standar tanpa logo/biaya,
  /// supaya pembayaran tetap bisa jalan. Biaya admin tetap dihitung server saat bayar (bila ada).
  static List<PayChannelV> _fallback(int amount) => [
    PayChannelV(method: 'qris', code: 'QRIS', label: 'QRIS', total: amount),
    for (final (k, v) in const [('bca', 'BCA'), ('bni', 'BNI'), ('bri', 'BRI'), ('mandiri', 'Mandiri'), ('permata', 'Permata')])
      PayChannelV(method: 'va', vaBank: k, code: '${k.toUpperCase()}VA', label: '$v Virtual Account', total: amount),
    for (final (k, v) in const [('ovo', 'OVO'), ('dana', 'DANA'), ('shopeepay', 'ShopeePay')])
      PayChannelV(method: 'ewallet', ewallet: k, code: k.toUpperCase(), label: v, total: amount),
  ];

  bool _feeUnknown = false;

  Future<List<PayChannelV>> _load() async {
    List<PayChannelV> list;
    try {
      list = await ref.read(pasienAppApiProvider).paymentChannels(widget.amount);
      _feeUnknown = false;
    } on AppError catch (e) {
      if (e.type != ErrorCode.notFound) rethrow;
      list = _fallback(widget.amount);
      _feeUnknown = true;
    }
    // Belum ada pilihan → pilih kanal pertama yang tersedia (biasanya QRIS).
    final first = list.where((c) => c.available).firstOrNull;
    if (widget.value == null && first != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.value == null) widget.onChanged(first);
      });
    }
    return list;
  }

  @override
  void didUpdateWidget(PaymentChannelPicker old) {
    super.didUpdateWidget(old);
    if (old.amount != widget.amount) _future = _load();
  }

  Future<void> _pick(PayChannelV ch) async {
    if (_loadingCode != null || ch.code == widget.value?.code) return;
    HapticFeedback.selectionClick();
    setState(() => _loadingCode = ch.code);
    widget.onBusy?.call(true);
    var fresh = ch;
    if (!_feeUnknown) {
      try {
        final r = await ref
            .read(pasienAppApiProvider)
            .paymentChannels(widget.amount, code: ch.code);
        fresh = r.firstOrNull ?? ch;
      } catch (_) {
        // Gagal hitung ulang → pakai biaya dari daftar (server tetap menghitung saat bayar).
      }
    }
    if (!mounted) return;
    setState(() => _loadingCode = null);
    widget.onBusy?.call(false);
    widget.onChanged(fresh);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return FutureBuilder<List<PayChannelV>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Metode pembayaran gagal dimuat.', style: t.bodyStrong),
                const SizedBox(height: OlSpace.sm),
                OlButton.secondary(
                  label: 'Coba lagi',
                  icon: OlIcons.refresh,
                  onPressed: () => setState(() {
                    _future = _load();
                  }),
                ),
              ],
            ),
          );
        }
        final list = snap.data;
        if (list == null) return const SkeletonCard();
        if (list.isEmpty) {
          return OlCard(
            child: Text(
              'Belum ada metode pembayaran online yang aktif. Hubungi klinik.',
              style: t.body.copyWith(color: c.muted),
            ),
          );
        }
        final groups = <String, List<PayChannelV>>{};
        for (final ch in list) {
          groups.putIfAbsent(ch.group, () => []).add(ch);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (gi, g) in groups.entries.indexed) ...[
              if (gi > 0) const SizedBox(height: OlSpace.md),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(g.key.toUpperCase(), style: t.overline.copyWith(color: c.muted)),
              ),
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(OlRadius.card),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  children: [
                    for (final (i, ch) in g.value.indexed) ...[
                      if (i > 0) Divider(height: 1, indent: 72, color: c.line),
                      _ChannelTile(
                        channel: ch,
                        selected: ch.code == widget.value?.code,
                        loading: ch.code == _loadingCode,
                        feeUnknown: _feeUnknown,
                        onTap: ch.available ? () => _pick(ch) : null,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.selected,
    required this.loading,
    required this.onTap,
    this.feeUnknown = false,
  });

  final PayChannelV channel;
  final bool selected, loading, feeUnknown;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final ch = channel;
    return Opacity(
      opacity: ch.available ? 1 : .45,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OlRadius.card),
        child: AnimatedContainer(
          duration: OlMotion.of(context, OlMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.md, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? c.brandSoft.withValues(alpha: .55) : null,
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Row(
            children: [
              PayChannelLogo(channel: ch),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ch.label, style: t.bodyStrong),
                    Text(
                      !ch.available
                          ? 'Tidak tersedia untuk nominal ini'
                          : feeUnknown
                          ? 'Biaya admin mengikuti kanal'
                          : ch.fee > 0
                          ? 'Biaya admin ${Fmt.money(ch.fee)}'
                          : 'Tanpa biaya admin',
                      style: t.caption.copyWith(color: ch.fee > 0 || feeUnknown ? c.muted : c.ok),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: OlSpace.sm),
              SizedBox.square(
                dimension: 22,
                child: loading
                    ? CircularProgressIndicator(strokeWidth: 2.2, color: c.brand)
                    : Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 22,
                        color: selected ? c.brand : c.faint,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo kanal dari gateway (URL); cadangan: ikon metode.
/// Logo kanal yang tersedia di `assets/payment/` (kunci: qris, bca, bni, …). Lisensi: assets/payment/README.md.
const paymentLogoAssets = <String, String>{
  'qris': 'assets/payment/qris.svg',
  'bca': 'assets/payment/bca.svg',
  'bni': 'assets/payment/bni.svg',
  'bri': 'assets/payment/bri.svg',
  'mandiri': 'assets/payment/mandiri.svg',
  'permata': 'assets/payment/permata.svg',
  'ovo': 'assets/payment/ovo.svg',
  'dana': 'assets/payment/dana.svg',
  'shopeepay': 'assets/payment/shopeepay.svg',
};

/// Aset logo lokal untuk kanal (diutamakan di atas URL logo dari gateway).
String? _assetFor(PayChannelV ch) =>
    paymentLogoAssets[ch.vaBank ?? ch.ewallet ?? ch.method];

class PayChannelLogo extends StatelessWidget {
  const PayChannelLogo({super.key, required this.channel, this.width = 52, this.height = 34});
  final PayChannelV channel;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final fallback = OlIcon(
      switch (channel.method) {
        'va' => OlIcons.transfer,
        'ewallet' => OlIcons.cash,
        _ => OlIcons.qris,
      },
      color: c.brandDeep,
      size: 20,
    );
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line),
      ),
      alignment: Alignment.center,
      child: switch (_assetFor(channel)) {
        final asset? when asset.endsWith('.svg') => SvgPicture.asset(asset, fit: BoxFit.contain),
        final asset? => Image.asset(asset, fit: BoxFit.contain),
        null when channel.logo != null => Image.network(
          channel.logo!,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => fallback,
        ),
        null => fallback,
      },
    );
  }
}
