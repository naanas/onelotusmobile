import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';

const _segments = {'inactive_days': 'Lama tidak datang', 'package_low': 'Sisa paket sedikit', 'receivables': 'Punya piutang'};

/// OW-20 Kirim pengingat massal (WhatsApp): segmen, template, pratinjau jumlah penerima.
/// Pasien yang menolak promo otomatis dikecualikan; pengingat sejenis maks 1×/7 hari per pasien (server).
class PengingatPage extends ConsumerStatefulWidget {
  const PengingatPage({super.key});

  @override
  ConsumerState<PengingatPage> createState() => _PengingatPageState();
}

class _PengingatPageState extends ConsumerState<PengingatPage> {
  BillingApi get _api => ref.read(billingApiProvider);
  late final Future<List<TemplateV>> _templates = _api.templates();
  String _segment = 'inactive_days';
  int _days = 30;
  String? _templateId;
  ({int count, int optedOut, int recent, String sample})? _preview;
  bool _busy = false;

  Map<String, dynamic> get _body => {
    'segment': {'type': _segment, if (_segment == 'inactive_days') 'days': _days},
    'template_id': _templateId,
  };

  Future<void> _check() async {
    setState(() => _busy = true);
    final p = await runApi(context, () => _api.campaignPreview(_body));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = p;
    });
  }

  Future<void> _send() async {
    final p = _preview!;
    final ok = await context.feedback.confirm(
      ConfirmSpec(title: 'Kirim ke ${p.count} pasien?', message: 'Pesan WhatsApp diantre dan dikirim bertahap.', confirmLabel: 'Kirim'),
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final n = await runApi(context, () => _api.sendCampaign(_body));
    if (!mounted) return;
    setState(() => _busy = false);
    if (n == null) return;
    context.feedback.success('$n pesan diantre.');
    context.pop();
  }

  void _changed(VoidCallback f) => setState(() {
    f();
    _preview = null;
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final p = _preview;
    return OlDetailScaffold(
      title: 'Kirim pengingat',
      foot: [
        if (p == null)
          OlButton.secondary(label: 'Cek penerima', loading: _busy, onPressed: _templateId == null ? null : _check)
        else
          OlButton(label: 'Kirim ke ${p.count} pasien', icon: OlIcons.send, loading: _busy, onPressed: p.count == 0 ? null : _send),
      ],
      children: [
        const OlSectionHeader(title: 'Segmen'),
        Wrap(
          spacing: OlSpace.sm,
          runSpacing: OlSpace.sm,
          children: [
            for (final MapEntry(:key, :value) in _segments.entries)
              OlChip(label: value, selected: _segment == key, onTap: () => _changed(() => _segment = key)),
          ],
        ),
        if (_segment == 'inactive_days')
          OlSegmented<int>(
            segments: const {30: '30 hari', 60: '60 hari', 90: '90 hari'},
            value: _days,
            onChanged: (d) => _changed(() => _days = d),
          ),
        const OlSectionHeader(title: 'Template'),
        OlAsync<List<TemplateV>>(
          load: () => _templates,
          builder: (context, all, _) {
            final list = [for (final x in all) if (x.kind == 'wa_message' && x.isActive) x];
            if (list.isEmpty) return [Text('Belum ada template WhatsApp aktif. Buat di Template pesan.', style: t.body.copyWith(color: c.muted))];
            return [
              OlSelectField<String?>(
                label: 'Template pesan',
                sheetTitle: 'Pilih template',
                value: _templateId,
                options: {null: 'Pilih template', for (final x in list) x.id: x.title},
                onChanged: (v) => _changed(() => _templateId = v),
              ),
            ];
          },
        ),
        if (p != null) ...[
          const OlSectionHeader(title: 'Pratinjau'),
          OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.count} penerima', style: t.heading),
                Text('Dilewati: ${p.optedOut} menolak promo · ${p.recent} sudah diingatkan 7 hari terakhir', style: t.caption.copyWith(color: c.muted)),
                if (p.sample.isNotEmpty) ...[
                  const SizedBox(height: OlSpace.md),
                  Container(
                    padding: const EdgeInsets.all(OlSpace.md),
                    decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(OlRadius.input)),
                    child: Text(p.sample, style: t.body),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
