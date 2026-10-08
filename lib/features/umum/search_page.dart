import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../terapis/demo_data.dart';

/// UM-10 Pencarian global: pasien (nama/nomor/4 digit HP) lalu sesi hari ini.
/// Hasil muncul sejak 2 huruf; riwayat pencarian terakhir.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  final _recent = ['#0412', 'Budi'];
  String _q = '';

  static const _extra = [
    DemoPatientRow(
      id: 'p0291',
      initials: 'RA',
      name: 'Rina Anggraini',
      number: '#0291',
      area: 'Bahu kanan',
      lastVisit: '12 Agu',
    ),
  ];
  static const _sessions = [
    ('09.00', 'Rina Setiawati', 'Cedera ringan · sesi 4/5', 's1'),
    ('10.30', 'Andi Pratama', 'Adjustment Therapy · ruang 2', 's2'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(String v) => setState(() => _q = v.trim());

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final q = _q.toLowerCase().replaceFirst('#', '');
    final active = q.length >= 2;
    final patients = active
        ? [...demoMyPatients, ..._extra]
              .where(
                (p) => p.name.toLowerCase().contains(q) || p.number.contains(q),
              )
              .toList()
        : const <DemoPatientRow>[];
    final sessions = active
        ? _sessions.where((s) => s.$2.toLowerCase().contains(q)).toList()
        : const [];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            OlSpace.screen,
            12,
            OlSpace.screen,
            24,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.brand, width: 2),
                      boxShadow: [
                        BoxShadow(color: c.brandSoft, spreadRadius: 4),
                      ],
                    ),
                    child: Row(
                      children: [
                        OlIcon(OlIcons.search, color: c.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            autofocus: true,
                            onChanged: _set,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (v) {
                              if (v.trim().length >= 2 &&
                                  !_recent.contains(v.trim())) {
                                setState(() => _recent.insert(0, v.trim()));
                              }
                            },
                            style: t.body.copyWith(fontSize: 15),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: 'Cari pasien atau sesi',
                              hintStyle: t.body.copyWith(
                                fontSize: 15,
                                color: c.faint,
                              ),
                            ),
                          ),
                        ),
                        if (_q.isNotEmpty)
                          IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _ctrl.clear();
                              _set('');
                            },
                            icon: OlIcon(
                              OlIcons.close,
                              size: 18,
                              color: c.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: c.brand,
                    textStyle: t.button,
                  ),
                  child: const Text('Batal'),
                ),
              ],
            ),
            if (active) ...[
              const SizedBox(height: 16),
              OlOverline('Pasien · ${patients.length}'),
              const SizedBox(height: 10),
              if (patients.isEmpty)
                Text(
                  'Tidak ada pasien yang cocok.',
                  style: t.body.copyWith(color: c.muted),
                )
              else
                OlCard(
                  padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                  child: Column(
                    children: [
                      for (final (i, p) in patients.indexed)
                        _Row(
                          leading: OlAvatar(name: p.name),
                          title: p.name,
                          query: q,
                          subtitle: '${p.number} · ${p.area} · ${p.lastVisit}',
                          trailing: OlIcon(
                            OlIcons.chevronRight,
                            color: c.faint,
                            size: 20,
                          ),
                          divider: i < patients.length - 1,
                          onTap: () =>
                              context.push(Routes.terapisPasienDetail(p.id)),
                        ),
                    ],
                  ),
                ),
              if (sessions.isNotEmpty) ...[
                const SizedBox(height: 16),
                OlOverline('Sesi hari ini · ${sessions.length}'),
                const SizedBox(height: 10),
                OlCard(
                  padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
                  child: Column(
                    children: [
                      for (final s in sessions)
                        _Row(
                          leading: SizedBox(
                            width: 56,
                            child: Text(
                              s.$1,
                              style: t.mono.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: s.$2,
                          query: q,
                          subtitle: s.$3,
                          trailing: const OlTag('Selesai', tone: OlTagTone.ok),
                          divider: false,
                          onTap: () => context.push(Routes.terapisSesi(s.$4)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            const OlOverline('Pencarian terakhir'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final r in _recent)
                  OlChip(
                    label: r,
                    small: true,
                    onTap: () {
                      _ctrl.text = r;
                      _set(r);
                    },
                  ),
                if (_recent.isNotEmpty)
                  OlChip(
                    label: 'Hapus riwayat',
                    small: true,
                    onTap: () => setState(_recent.clear),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Cari dengan nama, nomor pasien (#0412), atau 4 digit akhir HP bila diizinkan.',
              style: t.body.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris hasil dengan bagian yang cocok disorot warna brand.
class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.title,
    required this.query,
    required this.subtitle,
    required this.trailing,
    required this.divider,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String query;
  final String subtitle;
  final Widget trailing;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final i = title.toLowerCase().indexOf(query);
    final style = t.bodyStrong.copyWith(fontSize: 15);
    final spans = i < 0
        ? [TextSpan(text: title)]
        : [
            TextSpan(text: title.substring(0, i)),
            TextSpan(
              text: title.substring(i, i + query.length),
              style: TextStyle(color: c.brand),
            ),
            TextSpan(text: title.substring(i + query.length)),
          ];
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: spans), style: style),
                  Text(subtitle, style: t.body.copyWith(color: c.muted)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
