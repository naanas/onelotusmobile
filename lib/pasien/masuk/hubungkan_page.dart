import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_session.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// PS-03 Hubungkan data lama: nomor HP cocok dengan pasien lama → konfirmasi
/// tanggal lahir (maks 3 percobaan). Nama disamarkan sampai terbukti.
class HubungkanPage extends ConsumerStatefulWidget {
  const HubungkanPage({super.key});

  @override
  ConsumerState<HubungkanPage> createState() => _HubungkanPageState();
}

class _HubungkanPageState extends ConsumerState<HubungkanPage> {
  // Contoh pasien lama dari mockup: Rina Setiawati, 12 Mei 1999.
  static const _answer = (12, 5, 1999);
  int? _day = 12;
  int? _month = 5;
  int? _year = 1999;
  int _attempts = 3;
  String? _error;
  bool _busy = false;

  Future<void> _pick({
    required String title,
    required List<int> values,
    required String Function(int) label,
    required ValueChanged<int> onPick,
  }) async {
    final v = await context.feedback.formSheet<int>(
      title: title,
      builder: (ctx, close) => SizedBox(
        height: 320,
        child: ListView(
          children: [
            for (final x in values)
              OlListItem(title: label(x), onTap: () => close(x)),
          ],
        ),
      ),
    );
    if (v != null) setState(() => onPick(v));
  }

  Future<void> _link() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if ((_day, _month, _year) != _answer) {
      setState(() {
        _busy = false;
        _attempts--;
        _error = _attempts > 0
            ? 'Tanggal lahir tidak cocok. Sisa $_attempts percobaan.'
            : 'Percobaan habis. Hubungi klinik untuk menghubungkan data.';
      });
      return;
    }
    context.feedback.success('Riwayat terapi Anda sudah terhubung.');
    ref.read(pasienSessionProvider.notifier).linked();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget box(String text, VoidCallback onTap, String label, bool focus) =>
        Expanded(
          child: Semantics(
            container: true,
            button: true,
            label: '$label: $text',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(OlRadius.input),
              onTap: _attempts > 0 ? onTap : null,
              child: Container(
                height: OlSize.input,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(OlRadius.input),
                  border: Border.all(
                    color: _error != null ? c.crit : (focus ? c.brand : c.line),
                    width: focus ? 2 : 1.5,
                  ),
                ),
                child: Text(text, style: t.body.copyWith(fontSize: 16)),
              ),
            ),
          ),
        );

    return OlDetailScaffold(
      title: 'Kami menemukan data Anda',
      showBack: false,
      background: c.surface,
      foot: [
        OlButton(
          label: 'Hubungkan',
          loading: _busy,
          onPressed: _attempts > 0 && _day != null ? _link : null,
        ),
      ],
      children: [
        Text(
          'Nomor ini terdaftar di One Lotus. Konfirmasi tanggal lahir untuk menghubungkan riwayat terapi Anda.',
          style: t.body.copyWith(fontSize: 15, color: c.muted),
        ),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: c.surfaceAlt.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Row(
            children: [
              const OlAvatar(name: 'Rina Setiawati', large: true),
              const SizedBox(width: OlSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ri•• Setia•••i',
                      semanticsLabel: 'Nama disamarkan',
                      style: t.bodyStrong.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pasien sejak Maret 2025 · Klinik Pusat Malang',
                      style: t.body.copyWith(fontSize: 14, color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                text: 'Tanggal lahir',
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: c.crit),
                  ),
                ],
              ),
              style: t.fieldLabel,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                box(
                  '${_day ?? '–'}',
                  () => _pick(
                    title: 'Tanggal',
                    values: [for (var i = 1; i <= 31; i++) i],
                    label: (x) => '$x',
                    onPick: (v) => _day = v,
                  ),
                  'Tanggal',
                  true,
                ),
                const SizedBox(width: OlSpace.md),
                box(
                  _month == null ? '–' : _months[_month! - 1],
                  () => _pick(
                    title: 'Bulan',
                    values: [for (var i = 1; i <= 12; i++) i],
                    label: (x) => _months[x - 1],
                    onPick: (v) => _month = v,
                  ),
                  'Bulan',
                  false,
                ),
                const SizedBox(width: OlSpace.md),
                box(
                  '${_year ?? '–'}',
                  () => _pick(
                    title: 'Tahun',
                    values: [for (var i = 2015; i >= 1930; i--) i],
                    label: (x) => '$x',
                    onPick: (v) => _year = v,
                  ),
                  'Tahun',
                  false,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _error ??
                  'Sisa $_attempts percobaan. Setelah itu, hubungi klinik untuk menghubungkan data.',
              style: t.body.copyWith(
                fontSize: 14,
                color: _error != null ? c.crit : c.muted,
              ),
            ),
          ],
        ),
        Divider(color: c.line, height: 1),
        Center(
          child: OlButton.text(
            label: 'Bukan saya — daftar sebagai pasien baru',
            onPressed: () => ref.read(pasienSessionProvider.notifier).linked(),
          ),
        ),
      ],
    );
  }
}
