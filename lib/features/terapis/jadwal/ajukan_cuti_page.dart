import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

/// TR-03 Ajukan cuti → menunggu persetujuan owner (OW-06).
class AjukanCutiPage extends StatefulWidget {
  const AjukanCutiPage({super.key});

  @override
  State<AjukanCutiPage> createState() => _AjukanCutiPageState();
}

class _AjukanCutiPageState extends State<AjukanCutiPage> {
  DateTime _start = DateTime(2026, 10, 14);
  DateTime _end = DateTime(2026, 10, 15);
  String _duration = 'full';
  String? _reason = 'Keluarga';
  final _note = TextEditingController(text: 'Acara keluarga di Surabaya.');
  bool _busy = false;
  String? _reasonError;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2026, 10, 1),
      lastDate: DateTime(2027, 12, 31),
      locale: const Locale('id'),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked.isBefore(_start) ? _start : picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _reasonError = 'Pilih alasan cuti.');
      return;
    }
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    context.feedback.success(
      'Pengajuan cuti terkirim. Menunggu persetujuan owner.',
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    return OlDetailScaffold(
      title: 'Ajukan cuti',
      close: true,
      foot: [
        OlButton(label: 'Kirim pengajuan', loading: _busy, onPressed: _submit),
      ],
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DateField(
                label: 'Mulai',
                value: _start,
                onTap: () => _pick(true),
              ),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: _DateField(
                label: 'Selesai',
                value: _end,
                onTap: () => _pick(false),
              ),
            ),
          ],
        ),
        Text('Durasi', style: t.fieldLabel),
        OlSegmented<String>(
          segments: const {'full': 'Seharian', 'hours': 'Jam tertentu'},
          value: _duration,
          onChanged: (v) => setState(() => _duration = v),
        ),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Alasan'),
              TextSpan(
                text: ' *',
                style: TextStyle(color: c.crit),
              ),
            ],
          ),
          style: t.fieldLabel,
        ),
        Wrap(
          spacing: OlSpace.sm,
          children: [
            for (final r in const ['Sakit', 'Keluarga', 'Pelatihan', 'Lainnya'])
              OlChip(
                label: r,
                selected: _reason == r,
                onTap: () => setState(() {
                  _reason = r;
                  _reasonError = null;
                }),
              ),
          ],
        ),
        if (_reasonError != null)
          Text(
            _reasonError!,
            style: t.caption.copyWith(
              color: c.crit,
              fontWeight: FontWeight.w600,
            ),
          ),
        OlTextField(label: 'Catatan', controller: _note, maxLines: 3),
        const OlBanner(
          tone: OlBannerTone.warn,
          message:
              '3 sesi terjadwal di rentang ini\nOwner akan memindahkannya ke terapis lain setelah menyetujui.',
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: label),
              TextSpan(
                text: ' *',
                style: TextStyle(color: c.crit),
              ),
            ],
          ),
          style: t.fieldLabel,
        ),
        const SizedBox(height: 7),
        Semantics(
          container: true,
          button: true,
          label: '$label: ${Fmt.dayShort(value)}',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(OlRadius.input),
            child: Container(
              height: OlSize.input,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(OlRadius.input),
                border: Border.all(color: c.line, width: 1.5),
              ),
              child: Text(
                Fmt.dayShort(value),
                style: t.body.copyWith(fontSize: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
