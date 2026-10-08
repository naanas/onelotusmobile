import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';
import '../demo_data.dart';

enum _Filter { all, activeMonth, away, packageLow }

/// TR-06 Pasien saya (tab Pasien terapis): urut kunjungan terakhir, penanda belum kembali >30 hari.
class PasienSayaPage extends StatefulWidget {
  const PasienSayaPage({super.key});

  @override
  State<PasienSayaPage> createState() => _PasienSayaPageState();
}

class _PasienSayaPageState extends State<PasienSayaPage> {
  _Filter _filter = _Filter.all;
  String _query = '';

  List<DemoPatientRow> get _rows {
    final q = _query.toLowerCase().replaceFirst('#', '');
    return demoMyPatients.where((p) {
      final match =
          q.isEmpty || p.name.toLowerCase().contains(q) || p.number.contains(q);
      final filter = switch (_filter) {
        _Filter.all => true,
        _Filter.activeMonth => p.activeThisMonth,
        _Filter.away => (p.daysAway ?? 0) > 30,
        _Filter.packageLow => (p.packageLeft ?? 99) <= 1,
      };
      return match && filter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final away = demoMyPatients.where((p) => (p.daysAway ?? 0) > 30).length;
    final rows = _rows;
    Widget chip(String label, _Filter f) => OlChip(
      label: label,
      selected: _filter == f,
      onTap: () => setState(() => _filter = f),
    );

    return OlPageBody(
      header: const OlAppHeader(
        title: 'Pasien saya',
        context_: '48 pasien pernah ditangani',
      ),
      children: [
        OlSearchField(
          hint: 'Cari nama atau #nomor',
          onChanged: (v) => setState(() => _query = v),
        ),
        Wrap(
          spacing: OlSpace.sm,
          children: [
            chip('Semua', _Filter.all),
            chip('Aktif bulan ini', _Filter.activeMonth),
            chip('Belum kembali >30 hari · $away', _Filter.away),
            chip('Paket hampir habis', _Filter.packageLow),
          ],
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
        else ...[
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, p) in rows.indexed)
                  OlListItem(
                    leading: OlAvatar(name: p.name),
                    title: p.name,
                    subtitle: '${p.number} · ${p.area} · ${p.lastVisit}',
                    trailing: _trailing(p),
                    divider: i < rows.length - 1,
                    onTap: () => context.push(Routes.terapisPasienDetail(p.id)),
                  ),
              ],
            ),
          ),
          if (_filter == _Filter.all && _query.isEmpty)
            Center(
              child: Text(
                'Memuat 20 berikutnya…',
                style: context.olText.caption.copyWith(fontSize: 13),
              ),
            ),
        ],
      ],
    );
  }

  Widget? _trailing(DemoPatientRow p) {
    if ((p.daysAway ?? 0) > 30) {
      return OlTag('${p.daysAway} hari', tone: OlTagTone.crit);
    }
    if (p.packageLeft != null && p.packageLeft! <= 1) {
      return OlTag('Sisa ${p.packageLeft}', tone: OlTagTone.warn);
    }
    if (p.homeVisit) return const OlTag('Home visit', tone: OlTagTone.warn);
    return null;
  }
}
