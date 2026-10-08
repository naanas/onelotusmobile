import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'demo_data.dart';

enum _Filter { active, package, unpaid, away, archived }

/// KS-03 Daftar pasien (tab Pasien kasir): cari nama/#nomor/4 digit HP, filter, tambah.
class KasirPasienPage extends StatefulWidget {
  const KasirPasienPage({super.key});

  @override
  State<KasirPasienPage> createState() => _KasirPasienPageState();
}

class _KasirPasienPageState extends State<KasirPasienPage> {
  _Filter _filter = _Filter.active;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase().replaceFirst('#', '');
    final rows = demoKasirPatients.where((p) {
      final match =
          q.isEmpty || p.name.toLowerCase().contains(q) || p.number.contains(q);
      return match &&
          switch (_filter) {
            _Filter.active => true,
            _Filter.package => p.package > 0,
            _Filter.unpaid => p.unpaid,
            _Filter.away => p.away,
            _Filter.archived => false,
          };
    }).toList();
    final unpaid = demoKasirPatients.where((p) => p.unpaid).length;
    Widget chip(String l, _Filter f) => OlChip(
      label: l,
      selected: _filter == f,
      onTap: () => setState(() => _filter = f),
    );

    return OlPageBody(
      header: OlAppHeader(
        title: 'Pasien',
        context_: '412 pasien aktif',
        actions: [
          OlButton(
            label: '+ Tambah',
            small: true,
            expand: false,
            onPressed: () => context.push(Routes.kasirPasienForm),
          ),
        ],
      ),
      children: [
        OlSearchField(
          hint: 'Nama, #nomor, atau 4 digit akhir HP',
          onChanged: (v) => setState(() => _q = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            chip('Aktif', _Filter.active),
            chip('Punya paket', _Filter.package),
            chip('Belum lunas · $unpaid', _Filter.unpaid),
            chip('>30 hari', _Filter.away),
            chip('Arsip', _Filter.archived),
          ],
        ),
        if (rows.isEmpty)
          OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptySearch,
              title: _filter == _Filter.archived
                  ? 'Belum ada pasien diarsipkan'
                  : 'Pasien tidak ditemukan',
              message:
                  'Coba nama lain, nomor pasien (#0412), atau ubah filter.',
              actionLabel: 'Tambah pasien',
              onAction: () => context.push(Routes.kasirPasienForm),
            ),
          )
        else
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, p) in rows.indexed)
                  OlListItem(
                    leading: OlAvatar(name: p.name),
                    title: p.name,
                    subtitle: '${p.number} · ${p.last}',
                    trailing: p.tag == null
                        ? null
                        : OlTag(
                            p.tag!,
                            tone: switch (p.tagKind) {
                              'warn' => OlTagTone.warn,
                              'outline' => OlTagTone.outline,
                              _ => OlTagTone.brand,
                            },
                          ),
                    divider: i < rows.length - 1,
                    onTap: () => context.push(Routes.kasirPasienDetail(p.id)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
