import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/billing_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'owner_widgets.dart';

/// Owner: formulir booking web tanpa login (pengganti Google Form).
/// Pembayaran online on → pasien langsung bayar lewat payment gateway dan jadwal terkunci.
/// Off → booking masuk sebagai permintaan, menunggu konfirmasi klinik (bayar di klinik).
class BookingWebPage extends ConsumerStatefulWidget {
  const BookingWebPage({super.key});

  /// Alamat form untuk dibagikan (opsional): `--dart-define=WEB_FORM_URL=https://...`.
  static const formUrl = String.fromEnvironment('WEB_FORM_URL');

  @override
  ConsumerState<BookingWebPage> createState() => _BookingWebPageState();
}

class _BookingWebPageState extends ConsumerState<BookingWebPage> {
  BillingApi get _api => ref.read(billingApiProvider);
  bool? _saving;

  Future<void> _set(bool on, void Function() reload) async {
    setState(() => _saving = on);
    final r = await runApi(context, () => _api.setWebBookingPayment(on));
    if (!mounted) return;
    setState(() => _saving = null);
    if (r == null) return;
    reload();
    context.feedback.success(
      r ? 'Pembayaran online di form web aktif.' : 'Pembayaran online dimatikan. Booking menunggu konfirmasi klinik.',
    );
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Formulir booking web',
    children: [
      OlAsync<bool>(
        load: _api.webBookingPayment,
        builder: (context, on, reload) {
          final c = context.ol;
          final t = context.olText;
          final value = _saving ?? on;
          return [
            OlCard(
              child: OwToggleRow(
                label: 'Pembayaran online',
                subtitle: value
                    ? 'Pasien memilih QRIS / VA / e-wallet dan langsung membayar. Jadwal terkunci otomatis.'
                    : 'Booking masuk sebagai permintaan dan menunggu konfirmasi klinik. Pembayaran di klinik.',
                value: value,
                onChanged: (v) => _saving == null ? _set(v, reload) : null,
              ),
            ),
            OlBanner(
              tone: OlBannerTone.info,
              message: 'Biaya admin tiap metode bayar mengikuti pengaturan kanal di Dupay, sama seperti di aplikasi pasien.',
            ),
            if (BookingWebPage.formUrl.isNotEmpty)
              OlCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(BookingWebPage.formUrl, style: t.body.copyWith(color: c.brand)),
                    ),
                    OlButton.text(
                      label: 'Salin',
                      small: true,
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: BookingWebPage.formUrl));
                        context.feedback.success('Tautan form disalin.');
                      },
                    ),
                  ],
                ),
              ),
          ];
        },
      ),
    ],
  );
}
