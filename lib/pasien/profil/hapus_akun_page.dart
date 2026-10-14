import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
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
    final api = ref.read(pasienApiProvider);
    try {
      await api.requestDeletionOtp();
      if (!mounted) return;
      setState(() => _busy = false);
      final code = await context.feedback.formSheet<String>(
        title: 'Masukkan kode',
        message: 'Kode 6 digit dikirim lewat WhatsApp.',
        builder: (ctx, close) {
          var v = '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OlTextField(
                label: 'Kode OTP',
                keyboardType: TextInputType.number,
                mono: true,
                onChanged: (s) => v = s.trim(),
              ),
              const SizedBox(height: OlSpace.lg),
              OlButton.danger(
                label: 'Hapus akun',
                onPressed: () {
                  if (v.length == 6) close(v);
                },
              ),
            ],
          );
        },
      );
      if (code == null || !mounted) return;
      setState(() => _busy = true);
      await api.requestDeletion(code);
      if (!mounted) return;
      context.feedback.success(
        'Permintaan hapus akun terkirim. Rekam medis tetap disimpan klinik.',
      );
      await ref.read(pasienSessionProvider.notifier).expire();
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final msg = e.fieldError('code');
      msg != null ? context.feedback.info(msg) : context.feedback.error(e);
    }
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
                'Akun aplikasi Anda dihapus dan Anda keluar dari semua perangkat.',
              ),
              point(
                OlIcons.lock,
                c.brand,
                'Rekam medis tetap disimpan klinik sesuai ketentuan yang berlaku, dengan akses terbatas.',
              ),
              point(
                OlIcons.package,
                c.warn,
                'Paket yang masih aktif tetap bisa dipakai di klinik dengan menunjukkan nomor pasien.',
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
              'Kami akan mengirim kode OTP lewat WhatsApp untuk konfirmasi.',
        ),
      ],
    );
  }
}
