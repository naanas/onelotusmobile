import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Report { omzet, layanan, terapis, retensi, homeVisit }

const _reportLabels = {
  _Report.omzet: 'Omzet',
  _Report.layanan: 'Layanan',
  _Report.terapis: 'Terapis',
  _Report.retensi: 'Retensi',
  _Report.homeVisit: 'Home visit',
};

/// OW-04 Laporan (tab Laporan owner): omzet per hari & metode, layanan,
/// terapis, retensi, home visit. Ekspor ke OW-05.
class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  _Report _report = _Report.omzet;

  @override
  Widget build(BuildContext context) {
    return OlPageBody(
      header: OlAppHeader(
        title: 'Laporan',
        context_: '1–6 Okt 2026 · semua cabang',
        actions: [
          OlButton.secondary(
            label: 'Ekspor',
            icon: OlIcons.download,
            small: true,
            expand: false,
            onPressed: () => context.push(Routes.ownerEkspor),
          ),
        ],
      ),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final (i, e) in _reportLabels.entries.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                OlChip(
                  label: e.value,
                  selected: _report == e.key,
                  onTap: () => setState(() => _report = e.key),
                ),
              ],
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: OlMotion.of(context),
          child: KeyedSubtree(
            key: ValueKey(_report),
            child: switch (_report) {
              _Report.omzet => const _Omzet(),
              _Report.layanan => const _SimpleTable(
                headers: ['LAYANAN', 'SESI', 'NILAI'],
                rows: [
                  ['Adjustment Therapy', '34', 'Rp4,3 jt'],
                  ['Masase cedera', '29', 'Rp2,6 jt'],
                  ['Relaksasi Premium', '11', 'Rp1,5 jt'],
                  ['Infrared', '9', 'Rp0,5 jt'],
                  ['Home visit', '6', 'Rp0,5 jt'],
                ],
                footer: ['Total', '89', 'Rp9,4 jt'],
              ),
              _Report.terapis => const _SimpleTable(
                headers: ['TERAPIS', 'SESI', 'OMZET'],
                rows: [
                  ['Dimas', '24', 'Rp3,8 jt'],
                  ['Fajar', '21', 'Rp3,1 jt'],
                  ['Laras', '17', 'Rp2,5 jt'],
                ],
                footer: ['Total', '62', 'Rp9,4 jt'],
              ),
              _Report.retensi => const _Retensi(),
              _Report.homeVisit => const _SimpleTable(
                headers: ['AREA', 'KUNJUNGAN', 'NILAI'],
                rows: [
                  ['Lowokwaru', '3', 'Rp0,9 jt'],
                  ['Sukun', '2', 'Rp0,6 jt'],
                  ['Blimbing', '1', 'Rp0,3 jt'],
                ],
                footer: ['Total', '6', 'Rp1,8 jt'],
              ),
            },
          ),
        ),
      ],
    );
  }
}

class _Omzet extends StatelessWidget {
  const _Omzet();

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Omzet 6 hari',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ),
                  const OlTag('▲ 9% vs Sep', tone: OlTagTone.ok),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Rp9,4 jt',
                style: t.mono.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const OlBarChart(
                height: 110,
                semanticLabel:
                    'Omzet per hari dalam juta rupiah: Kamis 1,3, Jumat 1,6, Sabtu 2,1, Minggu 0,4, Senin 1,8, Selasa 2,2.',
                bars: [
                  OlBar('Kam', 1.3),
                  OlBar('Jum', 1.6),
                  OlBar('Sab', 2.1),
                  OlBar('Min', 0.4, dim: true),
                  OlBar('Sen', 1.8),
                  OlBar('Sel', 2.2, highlight: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: OlSpace.gap),
        _SimpleTable(
          headers: const ['METODE', 'TRANSAKSI', 'NILAI'],
          rows: const [
            ['Tunai', '31', 'Rp3,6 jt'],
            ['QRIS', '24', 'Rp2,9 jt'],
            ['Transfer / VA', '6', 'Rp2,1 jt'],
            ['Pakai paket', '18', 'Rp0,8 jt'],
          ],
          footer: const ['Total', '79', 'Rp9,4 jt'],
          onRow: (_) => context.push(Routes.kasirRiwayat),
        ),
        const SizedBox(height: OlSpace.gap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Piutang',
                  value: 'Rp640.000',
                  sub: '3 tagihan',
                  onTap: () => context.push(Routes.kasirPiutang),
                ),
              ),
              const SizedBox(width: OlSpace.gap),
              const Expanded(
                child: _MiniStat(
                  label: 'Refund & diskon',
                  value: 'Rp410.000',
                  sub: '4,4% omzet',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OlSpace.gap),
        Text(
          'Ketuk baris untuk melihat daftar transaksinya.',
          style: t.body.copyWith(color: c.muted),
        ),
      ],
    );
  }
}

class _Retensi extends StatelessWidget {
  const _Retensi();

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pasien datang lagi ≤30 hari',
                style: t.body.copyWith(color: c.muted),
              ),
              const SizedBox(height: 4),
              Text('64%', style: t.display.copyWith(fontSize: 34)),
              const SizedBox(height: 12),
              const OlBarChart(
                height: 90,
                semanticLabel:
                    'Retensi per bulan: Juli 58, Agustus 61, September 62, Oktober 64 persen.',
                bars: [
                  OlBar('Jul', 58, display: '58%'),
                  OlBar('Agu', 61, display: '61%'),
                  OlBar('Sep', 62, display: '62%'),
                  OlBar('Okt', 64, display: '64%', highlight: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: OlSpace.gap),
        const _SimpleTable(
          headers: ['SEGMEN', 'PASIEN', 'PORSI'],
          rows: [
            ['Pasien baru', '48', '22%'],
            ['Datang lagi', '139', '64%'],
            ['Belum kembali >30 hari', '14', '6%'],
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.sub,
    this.onTap,
  });

  final String label;
  final String value;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlCard(
      onTap: onTap,
      semanticLabel: '$label $value, $sub',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.body.copyWith(color: c.muted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: t.mono.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(sub, style: t.body.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}

/// Tabel 3 kolom (label · angka · nilai) dengan baris total tebal.
class _SimpleTable extends StatelessWidget {
  const _SimpleTable({
    required this.headers,
    required this.rows,
    this.footer,
    this.onRow,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final List<String>? footer;
  final ValueChanged<int>? onRow;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    Widget row(List<String> r, {bool head = false, bool bold = false, int? i}) {
      final content = Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                r[0],
                style: head
                    ? t.overline
                    : t.body.copyWith(
                        fontSize: 15,
                        fontWeight: bold ? FontWeight.w700 : null,
                      ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                r[1],
                textAlign: TextAlign.right,
                style: head
                    ? t.overline
                    : t.mono.copyWith(
                        fontSize: 14,
                        fontWeight: bold ? FontWeight.w700 : null,
                      ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                r[2],
                textAlign: TextAlign.right,
                style: head
                    ? t.overline
                    : t.mono.copyWith(
                        fontSize: 14,
                        fontWeight: bold ? FontWeight.w700 : null,
                      ),
              ),
            ),
          ],
        ),
      );
      if (i == null || onRow == null) return content;
      return Semantics(
        container: true,
        button: true,
        label: '${r[0]}: ${r[1]} ${headers[1].toLowerCase()}, ${r[2]}',
        excludeSemantics: true,
        child: InkWell(onTap: () => onRow!(i), child: content),
      );
    }

    return OlCard(
      padding: const EdgeInsets.fromLTRB(OlSpace.lg, 4, OlSpace.lg, 4),
      child: Column(
        children: [
          row(headers, head: true),
          for (final (i, r) in rows.indexed) row(r, i: i),
          if (footer != null) row(footer!, bold: true),
        ],
      ),
    );
  }
}
