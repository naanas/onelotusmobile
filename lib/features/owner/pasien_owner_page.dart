import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Branch { all, pusat, batu, archived }

class _OwnerPatient {
  _OwnerPatient(
    this.id,
    this.name,
    this.number,
    this.branch,
    this.last, {
    this.tag,
    this.tone = OlTagTone.brand,
    this.archived = false,
  });

  final String id;
  final String name;
  final String number;
  final _Branch branch;
  final String last;
  final String? tag;
  final OlTagTone tone;
  bool archived;
}

/// OW-03 Pasien lintas cabang (tab Pasien owner): cari, filter cabang, arsip
/// & pulihkan, gabungkan data ganda.
class PasienOwnerPage extends StatefulWidget {
  const PasienOwnerPage({super.key});

  @override
  State<PasienOwnerPage> createState() => _PasienOwnerPageState();
}

class _PasienOwnerPageState extends State<PasienOwnerPage> {
  _Branch _filter = _Branch.all;
  String _q = '';
  bool _duplicate = true;

  final _patients = [
    _OwnerPatient(
      'p-0387',
      'Rina Setiawati',
      '#0387',
      _Branch.pusat,
      '6 Okt',
      tag: 'Paket',
    ),
    _OwnerPatient(
      'p-0412',
      'Andi Pratama',
      '#0412',
      _Branch.pusat,
      'hari ini',
      tag: 'Belum lunas',
      tone: OlTagTone.warn,
    ),
    _OwnerPatient('p-b0088', 'Galih Tri', '#B-0088', _Branch.batu, '4 Okt'),
    _OwnerPatient(
      'p-0301',
      'Lestari Kusuma',
      '#0301',
      _Branch.pusat,
      '18 Agu',
      tag: '49 hari',
      tone: OlTagTone.crit,
    ),
    _OwnerPatient(
      'p-0156',
      'Hari Wibowo',
      '#0156',
      _Branch.pusat,
      '',
      archived: true,
    ),
  ];

  Future<void> _merge() async {
    final ok = await context.feedback.confirm(
      const ConfirmSpec(
        title: 'Gabungkan data pasien?',
        message:
            'Rina Setiawati #0102 digabung ke #0387. Riwayat sesi, paket, dan poin '
            'dipindah ke #0387. Tindakan ini dicatat di audit log.',
        confirmLabel: 'Gabungkan',
        danger: false,
      ),
    );
    if (ok && mounted) {
      setState(() => _duplicate = false);
      context.feedback.success('Data digabung ke #0387.');
    }
  }

  void _restore(_OwnerPatient p) {
    setState(() => p.archived = false);
    context.feedback.success('${p.name} dipulihkan.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final q = _q.toLowerCase().replaceFirst('#', '');
    final archivedCount = 26;
    final rows = _patients.where((p) {
      final match =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.number.toLowerCase().contains(q);
      return match &&
          switch (_filter) {
            _Branch.all => true,
            _Branch.archived => p.archived,
            final b => p.branch == b && !p.archived,
          };
    }).toList();
    Widget chip(String l, _Branch f) => OlChip(
      label: l,
      selected: _filter == f,
      onTap: () => setState(() => _filter = f),
    );

    return OlPageBody(
      header: const OlAppHeader(
        title: 'Pasien',
        context_: 'Semua cabang · 538 pasien',
      ),
      children: [
        OlSearchField(
          hint: 'Cari di semua cabang',
          onChanged: (v) => setState(() => _q = v),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final (i, (l, f)) in [
                ('Semua cabang', _Branch.all),
                ('Pusat', _Branch.pusat),
                ('Batu', _Branch.batu),
                ('Arsip · $archivedCount', _Branch.archived),
              ].indexed) ...[if (i > 0) const SizedBox(width: 8), chip(l, f)],
            ],
          ),
        ),
        if (_duplicate && _filter != _Branch.archived)
          Container(
            padding: const EdgeInsets.all(OlSpace.lg),
            decoration: BoxDecoration(
              color: c.warnSoft,
              borderRadius: BorderRadius.circular(OlRadius.card),
            ),
            child: Row(
              children: [
                OlIcon(OlIcons.users, color: c.warn),
                const SizedBox(width: OlSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2 kemungkinan data ganda',
                        style: t.bodyStrong.copyWith(
                          fontSize: 16,
                          color: c.warn,
                        ),
                      ),
                      Text(
                        'Rina Setiawati (#0387 & #0102)',
                        style: t.body.copyWith(color: c.warn),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: OlSpace.sm),
                OlButton(
                  label: 'Gabungkan',
                  small: true,
                  expand: false,
                  onPressed: _merge,
                ),
              ],
            ),
          ),
        if (rows.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptySearch,
              title: 'Pasien tidak ditemukan',
              message:
                  'Coba nama lain, nomor pasien (#0412), atau ubah filter.',
            ),
          )
        else
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, p) in rows.indexed)
                  Opacity(
                    opacity: p.archived ? 0.55 : 1,
                    child: OlListItem(
                      leading: OlAvatar(name: p.name),
                      title: p.name,
                      subtitle: p.archived
                          ? '${p.number} · diarsipkan'
                          : '${p.number} · ${p.branch == _Branch.batu ? 'Batu' : 'Pusat'} · ${p.last}',
                      trailing: p.archived
                          ? OlButton.text(
                              label: 'Pulihkan',
                              onPressed: () => _restore(p),
                            )
                          : p.tag == null
                          ? null
                          : OlTag(p.tag!, tone: p.tone),
                      divider: i < rows.length - 1,
                      onTap: p.archived
                          ? null
                          : () => context.push(Routes.kasirPasienDetail(p.id)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
