import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// OW-16 Pengumuman staf: judul, isi, penerima (peran × cabang), kirim sekarang
/// atau dijadwalkan. Muncul di pusat notifikasi staf.
class PengumumanPage extends StatefulWidget {
  const PengumumanPage({super.key});

  @override
  State<PengumumanPage> createState() => _PengumumanPageState();
}

class _PengumumanPageState extends State<PengumumanPage> {
  final _title = TextEditingController(text: 'Pelatihan kinesio taping');
  final _body = TextEditingController(
    text:
        'Sabtu 17 Okt pukul 14.00 di Klinik Pusat. Wajib untuk semua terapis, kasir boleh ikut.',
  );
  final _roles = {'Terapis', 'Kasir'};
  final _branches = {'Klinik Pusat', 'Cabang Batu'};
  bool _scheduled = false;
  DateTime _at = DateTime(2026, 10, 7, 8);

  // Jumlah staf contoh per peran × cabang.
  static const _headcount = {
    ('Terapis', 'Klinik Pusat'): 4,
    ('Terapis', 'Cabang Batu'): 3,
    ('Kasir', 'Klinik Pusat'): 2,
    ('Kasir', 'Cabang Batu'): 2,
    ('Owner', 'Klinik Pusat'): 1,
    ('Owner', 'Cabang Batu'): 0,
  };

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  int get _recipients => [
    for (final r in _roles)
      for (final b in _branches) _headcount[(r, b)] ?? 0,
  ].fold(0, (a, b) => a + b);

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2026, 10, 6),
      lastDate: DateTime(2026, 12, 31),
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (tm == null) return;
    setState(() => _at = DateTime(d.year, d.month, d.day, tm.hour, tm.minute));
  }

  void _send() {
    context.feedback.success(
      _scheduled
          ? 'Dijadwalkan ${Fmt.dayShort(_at)} ${Fmt.time(_at)} ke $_recipients staf.'
          : 'Terkirim ke $_recipients staf.',
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final n = _recipients;
    final valid =
        _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty && n > 0;
    Widget toggle(Set<String> set, String v) => OlChip(
      label: v,
      selected: set.contains(v),
      onTap: () => setState(() => set.contains(v) ? set.remove(v) : set.add(v)),
    );

    return OlDetailScaffold(
      title: 'Pengumuman staf',
      foot: [
        OlButton(
          label: n == 0
              ? 'Pilih penerima'
              : (_scheduled ? 'Jadwalkan ke $n staf' : 'Kirim ke $n staf'),
          onPressed: valid ? _send : null,
        ),
      ],
      children: [
        OlTextField(
          label: 'Judul',
          isRequired: true,
          controller: _title,
          onChanged: (_) => setState(() {}),
        ),
        OlTextField(
          label: 'Isi',
          isRequired: true,
          controller: _body,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Penerima', style: t.fieldLabel),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final r in const ['Terapis', 'Kasir', 'Owner'])
                  toggle(_roles, r),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final b in const ['Klinik Pusat', 'Cabang Batu'])
                  toggle(_branches, b),
              ],
            ),
          ],
        ),
        Text('Kirim', style: t.fieldLabel),
        OlSegmented<bool>(
          segments: const {false: 'Sekarang', true: 'Jadwalkan'},
          value: _scheduled,
          onChanged: (v) => setState(() => _scheduled = v),
        ),
        if (_scheduled)
          OlButton.secondary(
            label: '${Fmt.dayShort(_at)} · ${Fmt.time(_at)}',
            icon: OlIcons.clock,
            onPressed: _pickTime,
          ),
        const OlOverline('TERKIRIM SEBELUMNYA'),
        const OlCard(
          child: _InfoBlock(
            title: 'Jam buka Hari Sumpah Pemuda',
            subtitle: 'Semua staf · 1 Okt · dibaca 9/11',
          ),
        ),
        Text(
          'Pengumuman muncul di pusat notifikasi staf. Untuk pasien, gunakan Kirim pengingat massal.',
          style: t.body.copyWith(fontSize: 14, color: c.muted),
        ),
      ],
    );
  }
}

/// Judul + subjudul sederhana di dalam kartu.
class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.bodyStrong.copyWith(fontSize: 16)),
        const SizedBox(height: 2),
        Text(subtitle, style: t.body.copyWith(color: context.ol.muted)),
      ],
    );
  }
}
