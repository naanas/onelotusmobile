import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';
import '../demo_data.dart';

/// TR-08 Detail sesi & addendum: baca-saja; edit oleh pembuat sampai batas waktu,
/// setelahnya hanya addendum. Riwayat perubahan terlihat.
class DetailSesiPage extends StatefulWidget {
  const DetailSesiPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<DetailSesiPage> createState() => _DetailSesiPageState();
}

class _DetailSesiPageState extends State<DetailSesiPage> {
  final _addenda = <String>[];

  Future<void> _addAddendum() async {
    final text = await context.feedback.formSheet<String>(
      title: 'Tambah addendum',
      message:
          'Catatan asli tidak berubah. Addendum tercatat dengan nama & waktu.',
      builder: (context, close) => _AddendumForm(onSubmit: close),
    );
    if (text != null && mounted) {
      setState(() => _addenda.add(text));
      context.feedback.success('Addendum tersimpan.');
    }
  }

  Future<void> _delete() async {
    final ok = await context.feedback.confirm(
      const ConfirmSpec(
        title: 'Hapus catatan sesi 6 Okt?',
        message:
            'Hanya pembuat atau admin yang bisa menghapus. Penghapusan tercatat di audit log.',
        confirmLabel: 'Hapus catatan',
      ),
    );
    if (ok && mounted) {
      context.feedback.success('Catatan sesi dihapus.');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    const d = demoRinaSession;

    return OlDetailScaffold(
      title: d.patient,
      context_: d.when,
      actions: [
        OlButton.secondary(
          label: 'Edit',
          icon: OlIcons.edit,
          small: true,
          expand: false,
          onPressed: () =>
              context.feedback.info('Edit membuka rekam sesi (TR-04).'),
        ),
      ],
      below: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const OlTag('Selesai', tone: OlTagTone.ok),
          const OlTag('Lunas', tone: OlTagTone.ok),
          Text(
            'Edit tersedia ${d.editHoursLeft} jam lagi',
            style: t.body.copyWith(color: c.muted),
          ),
        ],
      ),
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OlInfoRow(label: 'Keluhan', value: d.complaint, divider: true),
              const SizedBox(height: 4),
              OlInfoRow(label: 'Area ditangani', value: d.areas),
              OlInfoRow(
                label: 'Nyeri',
                value: '${d.painBefore}  →  ${d.painAfter}',
                valueStyle: t.heading.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              OlInfoRow(label: 'Treatment', value: d.treatments, divider: true),
              const SizedBox(height: 10),
              Text(
                'Analisa (internal)',
                style: t.body.copyWith(fontSize: 15, color: c.muted),
              ),
              const SizedBox(height: 6),
              Text(d.analysis, style: t.body.copyWith(fontSize: 15)),
              const SizedBox(height: 12),
              Text(
                'Kesimpulan & saran',
                style: t.body.copyWith(fontSize: 15, color: c.muted),
              ),
              const SizedBox(height: 6),
              Text(d.conclusion, style: t.body.copyWith(fontSize: 15)),
            ],
          ),
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Addendum',
                      style: t.heading.copyWith(fontSize: 17),
                    ),
                  ),
                  TextButton(
                    onPressed: _addAddendum,
                    style: TextButton.styleFrom(
                      foregroundColor: c.brand,
                      textStyle: t.button,
                    ),
                    child: const Text('+ Tambah'),
                  ),
                ],
              ),
              if (_addenda.isEmpty)
                Text(
                  'Tersedia setelah 24 jam — catatan asli tidak bisa diubah, tambahan ditulis di sini.',
                  style: t.body.copyWith(color: c.muted),
                )
              else
                for (final a in _addenda)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Dimas · baru saja — $a', style: t.body),
                  ),
            ],
          ),
        ),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Riwayat perubahan',
                style: t.heading.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 6),
              for (final (what, at) in d.changes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(what, style: t.body.copyWith(fontSize: 15)),
                      ),
                      Text(
                        at,
                        style: t.mono.copyWith(fontSize: 14, color: c.muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Center(
          child: OlButton(
            label: 'Hapus catatan',
            variant: OlButtonVariant.dangerText,
            expand: false,
            onPressed: _delete,
          ),
        ),
      ],
    );
  }
}

class _AddendumForm extends StatefulWidget {
  const _AddendumForm({required this.onSubmit});
  final ValueChanged<String> onSubmit;

  @override
  State<_AddendumForm> createState() => _AddendumFormState();
}

class _AddendumFormState extends State<_AddendumForm> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OlTextField(
        label: 'Isi addendum',
        isRequired: true,
        controller: _ctrl,
        maxLines: 4,
        error: _error,
      ),
      const SizedBox(height: OlSpace.lg),
      OlButton(
        label: 'Simpan addendum',
        onPressed: () {
          if (_ctrl.text.trim().isEmpty) {
            setState(() => _error = 'Tulis isi addendum.');
            return;
          }
          widget.onSubmit(_ctrl.text.trim());
        },
      ),
    ],
  );
}
