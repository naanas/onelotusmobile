import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Kind { cuti, refund, diskon, reset }

class _Request {
  const _Request({
    required this.id,
    required this.kind,
    required this.by,
    required this.title,
    required this.detail,
    this.facts = const [],
  });

  final String id;
  final _Kind kind;
  final String by;
  final String? title;
  final String detail;
  final List<(String, String, bool)> facts; // label, nilai, mono
}

const _kindLabels = {
  _Kind.cuti: 'Cuti',
  _Kind.refund: 'Refund',
  _Kind.diskon: 'Diskon',
  _Kind.reset: 'Reset password',
};

/// OW-06 Persetujuan: refund, cuti, diskon manual di atas batas, reset password.
/// Menolak wajib alasan; dampak (komisi, poin, sesi terdampak) tampil sebelum setuju.
class PersetujuanPage extends StatefulWidget {
  const PersetujuanPage({super.key});

  @override
  State<PersetujuanPage> createState() => _PersetujuanPageState();
}

class _PersetujuanPageState extends State<PersetujuanPage> {
  _Kind? _filter;
  final _items = <_Request>[
    const _Request(
      id: 'r1',
      kind: _Kind.refund,
      by: 'diajukan Sinta · 11.40',
      title: 'Refund penuh Rp450.000',
      detail:
          'Ilham Ramadhan · Adjustment Therapy 3 Okt · alasan: pasien tidak datang, sudah bayar di muka',
      facts: [
        ('Metode', 'Transfer manual', false),
        ('Komisi Laras', '-Rp62.500', true),
        ('Poin pasien', '-45', true),
      ],
    ),
    const _Request(
      id: 'c1',
      kind: _Kind.cuti,
      by: 'Dimas · kemarin',
      title: '14–15 Okt · keluarga',
      detail: '3 sesi terdampak → pindahkan setelah setuju',
    ),
    const _Request(
      id: 'd1',
      kind: _Kind.diskon,
      by: 'Sinta · 10.15',
      title: 'Diskon 25% · Rp112.500',
      detail: 'Hendra Gunawan · "pasien rujukan dokter mitra"',
    ),
    const _Request(
      id: 'p1',
      kind: _Kind.reset,
      by: 'laras.terapis · 08.02',
      title: null,
      detail: '"HP baru, lupa password lama."',
    ),
  ];

  Future<void> _approve(_Request r) async {
    setState(() => _items.remove(r));
    context.feedback.success(switch (r.kind) {
      _Kind.refund => 'Refund disetujui. Sinta diberi tahu untuk memproses.',
      _Kind.cuti => 'Cuti disetujui. Pindahkan 3 sesi terdampak.',
      _Kind.diskon => 'Diskon disetujui.',
      _Kind.reset => 'Password sementara dikirim ke Laras.',
    });
  }

  Future<void> _reject(_Request r) async {
    final res = await context.feedback.choose(
      ConfirmSpec(
        title: 'Tolak ${_kindLabels[r.kind]!.toLowerCase()}?',
        message: 'Pengaju menerima alasan penolakan.',
        confirmLabel: 'Tolak',
        reasonLabel: 'Alasan penolakan',
      ),
    );
    if (res.choice != ConfirmChoice.confirm || !mounted) return;
    setState(() => _items.remove(r));
    context.feedback.info('Ditolak. Pengaju diberi tahu.');
  }

  @override
  Widget build(BuildContext context) {
    final count = {
      for (final k in _Kind.values) k: _items.where((r) => r.kind == k).length,
    };
    final rows = _items
        .where((r) => _filter == null || r.kind == _filter)
        .toList();
    return OlDetailScaffold(
      title: 'Persetujuan',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OlChip(
              label: 'Semua ${_items.length}',
              selected: _filter == null,
              onTap: () => setState(() => _filter = null),
            ),
            for (final k in _Kind.values)
              if (count[k]! > 0)
                OlChip(
                  label: '${_kindLabels[k]} ${count[k]}',
                  selected: _filter == k,
                  onTap: () => setState(() => _filter = k),
                ),
          ],
        ),
        if (rows.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptyInbox,
              title: 'Semua sudah diputuskan',
              message: 'Permintaan baru akan muncul di sini dan di notifikasi.',
            ),
          ),
        for (final r in rows)
          _RequestCard(
            key: ValueKey(r.id),
            request: r,
            onApprove: () => _approve(r),
            onReject: () => _reject(r),
          ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final _Request request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final r = request;
    final (label, tone) = switch (r.kind) {
      _Kind.refund => ('Refund', OlTagTone.crit),
      _Kind.cuti => ('Cuti', OlTagTone.warn),
      _Kind.diskon => ('Diskon manual', OlTagTone.brand),
      _Kind.reset => ('Reset password', OlTagTone.muted),
    };
    return OlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OlTag(label, tone: tone),
              const SizedBox(width: OlSpace.sm),
              Expanded(
                child: Text(
                  r.by,
                  textAlign: TextAlign.right,
                  style: t.body.copyWith(fontSize: 14, color: c.muted),
                ),
              ),
            ],
          ),
          if (r.title != null) ...[
            const SizedBox(height: 10),
            Text(r.title!, style: t.heading.copyWith(fontSize: 17)),
          ],
          const SizedBox(height: 6),
          Text(
            r.detail,
            style: t.body.copyWith(
              fontSize: 14.5,
              color: r.kind == _Kind.refund ? c.fg : c.muted,
            ),
          ),
          if (r.facts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: c.brandSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (final (l, v, mono) in r.facts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l,
                              style: t.body.copyWith(
                                fontSize: 14.5,
                                color: c.muted,
                              ),
                            ),
                          ),
                          Text(
                            v,
                            style: mono
                                ? t.mono.copyWith(fontSize: 14)
                                : t.body.copyWith(fontSize: 14.5),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: OlSpace.md),
          OlFootRow(
            children: [
              OlButton(
                label: r.kind == _Kind.reset ? 'Reset' : 'Setujui',
                onPressed: onApprove,
              ),
              OlButton(
                label: 'Tolak',
                variant: OlButtonVariant.dangerSecondary,
                onPressed: onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
