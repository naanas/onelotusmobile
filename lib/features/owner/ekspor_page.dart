import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Kind { omzet, layanan, komisi, pasien, kas }

enum _Fmt { pdf, excel }

/// OW-05 Ekspor laporan: jenis, rentang tanggal, cabang, format. Data kontak
/// pasien hanya bila diaktifkan + alasan (UU PDP). Setiap ekspor masuk audit log.
class EksporPage extends StatefulWidget {
  const EksporPage({super.key});

  @override
  State<EksporPage> createState() => _EksporPageState();
}

class _EksporPageState extends State<EksporPage> {
  _Kind _kind = _Kind.omzet;
  DateTime _from = DateTime(2026, 10, 1);
  DateTime _to = DateTime(2026, 10, 6);
  String _branch = 'all';
  _Fmt _fmt = _Fmt.excel;
  bool _contacts = false;
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _valid => !_contacts || _reason.text.trim().isNotEmpty;

  Future<void> _pick(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2024),
      lastDate: DateTime(2026, 12, 31),
    );
    if (d == null) return;
    setState(() {
      if (from) {
        _from = d;
        if (_to.isBefore(d)) _to = d;
      } else {
        _to = d;
        if (_from.isAfter(d)) _from = d;
      }
    });
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _busy = false);
    context.feedback.success(
      'File ${_fmt == _Fmt.pdf ? 'PDF' : 'Excel'} siap & tercatat di audit log.',
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final fmtLabel = _fmt == _Fmt.pdf ? 'PDF' : 'Excel';
    return OlDetailScaffold(
      title: 'Ekspor laporan',
      close: true,
      foot: [
        OlButton(
          label: 'Buat file $fmtLabel',
          loading: _busy,
          onPressed: _valid ? _export : null,
        ),
      ],
      children: [
        OlSelectField<_Kind>(
          label: 'Jenis laporan',
          isRequired: true,
          sheetTitle: 'Jenis laporan',
          value: _kind,
          options: const {
            _Kind.omzet: 'Omzet & transaksi',
            _Kind.layanan: 'Layanan',
            _Kind.komisi: 'Komisi terapis',
            _Kind.pasien: 'Daftar pasien',
            _Kind.kas: 'Tutup kas harian',
          },
          onChanged: (v) => setState(() => _kind = v),
        ),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'Dari',
                value: _from,
                onTap: () => _pick(true),
              ),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: _DateField(
                label: 'Sampai',
                value: _to,
                onTap: () => _pick(false),
              ),
            ),
          ],
        ),
        Text('Cabang', style: t.fieldLabel),
        OlSegmented<String>(
          segments: const {'all': 'Semua', 'pusat': 'Pusat', 'batu': 'Batu'},
          value: _branch,
          onChanged: (v) => setState(() => _branch = v),
        ),
        Text('Format', style: t.fieldLabel),
        OlSegmented<_Fmt>(
          segments: const {_Fmt.pdf: 'PDF', _Fmt.excel: 'Excel'},
          value: _fmt,
          onChanged: (v) => setState(() => _fmt = v),
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sertakan data kontak pasien',
                          style: t.bodyStrong.copyWith(fontSize: 16),
                        ),
                        Text(
                          'Nomor HP & alamat',
                          style: t.body.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  OlToggle(
                    value: _contacts,
                    semanticLabel: 'Sertakan data kontak pasien',
                    onChanged: (v) => setState(() => _contacts = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Bila diaktifkan, alasan wajib diisi. Data kesehatan dilindungi UU PDP No. 27/2022.',
                style: t.body.copyWith(fontSize: 14, color: c.muted),
              ),
              if (_contacts) ...[
                const SizedBox(height: OlSpace.md),
                OlTextField(
                  label: 'Alasan',
                  isRequired: true,
                  hint: 'Mis. kirim pengingat kontrol lewat vendor SMS',
                  controller: _reason,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
        const OlBanner(
          icon: OlIcons.lock,
          message:
              'Setiap ekspor dicatat di audit log (siapa, kapan, isi apa).',
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
    final text = Fmt.dateNoDay(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: t.fieldLabel),
        const SizedBox(height: 8),
        Semantics(
          container: true,
          button: true,
          label: '$label: $text',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(OlRadius.input),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: OlSize.input),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(OlRadius.input),
                border: Border.all(color: c.line, width: 1.5),
              ),
              child: Text(text, style: t.body.copyWith(fontSize: 15)),
            ),
          ),
        ),
      ],
    );
  }
}
