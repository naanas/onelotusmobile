import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../demo_data.dart';
import '../pasien_session.dart';

/// PS-20 Hapus akun aplikasi (§10, UU PDP): jelaskan dampak, alasan opsional,
/// konfirmasi lewat OTP. Rekam medis tetap disimpan klinik sesuai ketentuan.
class HapusAkunPage extends ConsumerStatefulWidget {
  const HapusAkunPage({super.key});

  @override
  ConsumerState<HapusAkunPage> createState() => _HapusAkunPageState();
}

class _HapusAkunPageState extends ConsumerState<HapusAkunPage> {
  String? _reason;
  bool _busy = false;

  Future<void> _request() async {
    final r = await context.feedback.choose(
      const ConfirmSpec(
        title: 'Minta hapus akun?',
        message:
            'Kami kirim kode OTP ke WhatsApp Anda untuk konfirmasi. Permintaan diproses klinik dalam beberapa hari kerja.',
        confirmLabel: 'Kirim kode',
      ),
    );
    if (r.choice != ConfirmChoice.confirm || !mounted) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _busy = false);
    context.feedback.success(
      'Permintaan hapus akun terkirim. Status bisa dilihat di sini.',
    );
    ref.read(pasienSessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget point(OlIconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OlIcon(icon, color: color, weight: OlIconWeight.duotone),
          const SizedBox(width: OlSpace.lg),
          Expanded(child: Text(text, style: t.body.copyWith(fontSize: 14.5))),
        ],
      ),
    );

    return OlDetailScaffold(
      title: 'Hapus akun aplikasi',
      foot: [
        OlButton.danger(
          label: 'Kirim kode & minta hapus akun',
          loading: _busy,
          onPressed: _request,
        ),
        OlButton.text(
          label: 'Batal',
          expand: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
      children: [
        Text(
          'Kami menghormati hak Anda atas data pribadi. Sebelum melanjutkan, ini yang akan terjadi:',
          style: t.body.copyWith(fontSize: 15, color: c.muted),
        ),
        OlCard(
          child: Column(
            children: [
              point(
                OlIcons.close,
                c.crit,
                'Akun aplikasi, poin ($demoPoints), alamat tersimpan, dan program latihan akan dihapus.',
              ),
              point(
                OlIcons.lock,
                c.brand,
                'Rekam medis tetap disimpan klinik sesuai ketentuan yang berlaku, dengan akses terbatas.',
              ),
              point(
                OlIcons.package,
                c.warn,
                'Sisa 1 sesi paket tetap bisa dipakai di klinik dengan menunjukkan nomor pasien.',
              ),
            ],
          ),
        ),
        Text('Alasan (opsional)', style: t.fieldLabel),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final r in const [
              'Sudah pulih',
              'Jarang dipakai',
              'Privasi',
              'Lainnya',
            ])
              OlChip(
                label: r,
                selected: _reason == r,
                onTap: () => setState(() => _reason = _reason == r ? null : r),
              ),
          ],
        ),
        const OlBanner(
          message:
              'Kami akan mengirim kode OTP untuk konfirmasi. Status permintaan bisa dilihat di sini.',
        ),
      ],
    );
  }
}
