import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

/// TR-11 Kas dibawa & serah terima ke kasir (§6.4.7).
class KasDibawaPage extends StatefulWidget {
  const KasDibawaPage({super.key});

  @override
  State<KasDibawaPage> createState() => _KasDibawaPageState();
}

class _KasDibawaPageState extends State<KasDibawaPage> {
  bool _handedOver = false;

  Future<void> _handOver() async {
    final ok = await context.feedback.confirm(
      const ConfirmSpec(
        title: 'Serahkan Rp445.000 ke kasir?',
        message:
            'Kasir akan mengonfirmasi penerimaan. Setelah diterima, kas ini tidak lagi tercatat di kamu.',
        confirmLabel: 'Serahkan ke kasir',
        danger: false,
      ),
    );
    if (ok && mounted) {
      setState(() => _handedOver = true);
      context.feedback.success('Menunggu konfirmasi kasir.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget row(
      String time,
      String name,
      String place,
      String amount, {
      bool divider = true,
    }) => Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              time,
              style: t.mono.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: t.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(place, style: t.body.copyWith(color: c.muted)),
              ],
            ),
          ),
          Text(
            amount,
            style: t.mono.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

    return OlDetailScaffold(
      title: 'Kas dibawa',
      foot: [
        OlButton(
          label: _handedOver
              ? 'Menunggu konfirmasi kasir'
              : 'Serahkan ke kasir',
          onPressed: _handedOver ? null : _handOver,
        ),
      ],
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tunai hari ini · Sel, 6 Okt',
                style: t.caption.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Rp445.000',
                style: t.mono.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              OlTag(
                _handedOver
                    ? 'Diserahkan · menunggu kasir'
                    : 'Dibawa · belum diserahkan',
                tone: _handedOver ? OlTagTone.brand : OlTagTone.warn,
              ),
            ],
          ),
        ),
        const OlOverline('Rincian'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              row('14.36', 'Budi Hartono', 'Home visit · Sukun', 'Rp295.000'),
              row(
                '17.10',
                'Wawan Hidayat',
                'Home visit · Blimbing',
                'Rp150.000',
                divider: false,
              ),
            ],
          ),
        ),
        const OlOverline('Sebelumnya'),
        OlCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sen, 5 Okt',
                      style: t.bodyStrong.copyWith(fontSize: 15),
                    ),
                    Text(
                      'Diterima oleh Sinta (kasir) 18.05',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              Text(
                'Rp320.000',
                style: t.mono.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              const OlTag('Diterima', tone: OlTagTone.ok),
            ],
          ),
        ),
        const OlBanner(
          message:
              'Serahkan sebelum kasir menutup kas. Kas yang belum diserahkan lebih dari 1 hari kerja akan diingatkan ke owner.',
        ),
      ],
    );
  }
}
