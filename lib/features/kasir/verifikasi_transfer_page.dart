import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-15 Verifikasi transfer manual: bandingkan bukti dengan tagihan.
/// Staf yang mengunggah bukti tidak bisa memverifikasi transaksinya sendiri.
class VerifikasiTransferPage extends StatefulWidget {
  const VerifikasiTransferPage({super.key});

  @override
  State<VerifikasiTransferPage> createState() => _VerifikasiTransferPageState();
}

class _VerifikasiTransferPageState extends State<VerifikasiTransferPage> {
  int _pending = 2;
  bool _done = false;

  Future<void> _reject() async {
    final r = await context.feedback.choose(
      const ConfirmSpec(
        title: 'Tolak bukti transfer Lestari Kusuma?',
        message:
            'Tagihan kembali Belum bayar dan pasien diberi tahu beserta alasannya.',
        confirmLabel: 'Tolak',
        reasonLabel: 'Alasan',
      ),
    );
    if (r.confirmed) _finish('Bukti ditolak. Pasien diberi tahu.');
  }

  void _finish(String msg) {
    setState(() {
      _done = true;
      _pending--;
    });
    context.feedback.success(msg);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Verifikasi transfer',
      context_: '$_pending menunggu verifikasi',
      children: [
        if (!_done)
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lestari Kusuma',
                            style: t.heading.copyWith(fontSize: 17),
                          ),
                          Text(
                            'Paket Adjustment 5× · diunggah pasien 09.12',
                            style: t.body.copyWith(color: c.muted),
                          ),
                        ],
                      ),
                    ),
                    const OlTag('Menunggu', tone: OlTagTone.warn),
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  container: true,
                  button: true,
                  label:
                      'Bukti transfer BRI, Lestari Kusuma, Rp1.125.000. Ketuk untuk memperbesar',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () =>
                        context.feedback.info('Membuka foto bukti transfer…'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(OlSpace.lg),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.line, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Bukti transfer',
                            style: t.bodyStrong.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          const OlInfoRow(label: 'Bank pengirim', value: 'BRI'),
                          const OlInfoRow(
                            label: 'Nama',
                            value: 'LESTARI KUSUMA',
                          ),
                          OlInfoRow(
                            label: 'Tanggal',
                            value: '06/10/2026 09:08',
                            valueStyle: t.mono.copyWith(fontSize: 14.5),
                          ),
                          OlInfoRow(
                            label: 'Nominal',
                            value: 'Rp1.125.000',
                            valueStyle: t.mono.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Ketuk untuk memperbesar',
                            style: t.body.copyWith(color: c.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OlInfoRow(
                  label: 'Nominal tagihan',
                  value: 'Rp1.125.000',
                  valueStyle: t.mono.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const OlInfoRow(
                  label: 'Rekening tujuan',
                  value: 'BCA One Lotus',
                ),
                const SizedBox(height: 4),
                const SyncIndicator(
                  status: SyncSynced(),
                  label: 'Nominal cocok',
                ),
                const SizedBox(height: 14),
                OlFootRow(
                  children: [
                    OlButton(
                      label: 'Setujui',
                      onPressed: () =>
                          _finish('Transfer diverifikasi. Tagihan lunas.'),
                    ),
                    OlButton(
                      label: 'Tolak',
                      variant: OlButtonVariant.dangerSecondary,
                      onPressed: _reject,
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.successPayment,
              title: 'Tinggal 1 menunggu',
              message: 'Bukti transfer berikutnya muncul di sini.',
            ),
          ),
        Text(
          'Staf yang mengunggah bukti tidak bisa memverifikasi transaksinya sendiri. Penolakan wajib alasan dan pasien diberi tahu.',
          style: t.body.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
