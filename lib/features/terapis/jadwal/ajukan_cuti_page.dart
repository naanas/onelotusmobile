import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../data/api/one_lotus_api.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

/// TR-03 Ajukan cuti → menunggu persetujuan owner (OW-06).
class AjukanCutiPage extends ConsumerStatefulWidget {
  const AjukanCutiPage({super.key});

  @override
  ConsumerState<AjukanCutiPage> createState() => _AjukanCutiPageState();
}

class _AjukanCutiPageState extends ConsumerState<AjukanCutiPage> {
  late DateTime _start = DateUtils.dateOnly(DateTime.now());
  late DateTime _end = _start;
  String _duration = 'full';
  TimeOfDay _from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 12, minute: 0);
  String? _reason;
  final _note = TextEditingController();
  bool _busy = false;
  String? _reasonError;
  String? _dateError;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  Future<void> _pickTime(bool from) async {
    final t = await showTimePicker(
      context: context,
      initialTime: from ? _from : _to,
    );
    if (t != null) setState(() => from ? _from = t : _to = t);
  }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _reasonError = 'Pilih alasan cuti.');
      return;
    }
    final allDay = _duration == 'full';
    DateTime at(DateTime d, TimeOfDay t) =>
        DateTime(d.year, d.month, d.day, t.hour, t.minute);
    final startsAt = allDay ? _start : at(_start, _from);
    final endsAt = allDay ? _end : at(_start, _to);
    if (!allDay && !endsAt.isAfter(startsAt)) {
      setState(() => _dateError = 'Jam selesai harus setelah jam mulai.');
      return;
    }
    setState(() {
      _busy = true;
      _dateError = null;
    });
    try {
      final leave = await ref
          .read(oneLotusApiProvider)
          .createLeave(
            startsAt: startsAt,
            endsAt: endsAt,
            allDay: allDay,
            reason: _reason!,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (!mounted) return;
      context.feedback.success(
        leave.affectedSessions > 0
            ? 'Pengajuan cuti terkirim. ${leave.affectedSessions} sesi terjadwal akan dipindahkan setelah disetujui.'
            : 'Pengajuan cuti terkirim. Menunggu persetujuan owner.',
      );
      Navigator.of(context).maybePop();
    } on AppError catch (e) {
      if (!mounted) return;
      final msg =
          e.fieldError('starts_at') ??
          e.fieldError('ends_at') ??
          e.fieldError('reason');
      setState(() {
        _busy = false;
        _dateError = msg;
      });
      if (msg == null) context.feedback.error(e, retry: _submit);
    }
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
        if (_duration == 'hours')
          Row(
            children: [
              Expanded(
                child: OlButton.secondary(
                  label: 'Dari ${_from.format(context)}',
                  onPressed: () => _pickTime(true),
                ),
              ),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: OlButton.secondary(
                  label: 'Sampai ${_to.format(context)}',
                  onPressed: () => _pickTime(false),
                ),
              ),
            ],
          ),
        if (_dateError != null)
          Text(
            _dateError!,
            style: t.caption.copyWith(
              color: c.crit,
              fontWeight: FontWeight.w600,
            ),
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
          message:
              'Sesi terjadwal di rentang cuti akan dipindahkan owner ke terapis lain setelah disetujui.',
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
