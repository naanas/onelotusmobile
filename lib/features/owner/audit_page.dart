import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Filter { today, all, export, edit, xray }

enum _Kind { action, view, edit, export, security }

typedef _Log = ({String time, String title, String detail, _Kind kind});

const _logs = <_Log>[
  (
    time: '11.40',
    title: 'Sinta mengajukan refund',
    detail: 'STR-PST-02791 · Ilham Ramadhan · HP Samsung A54',
    kind: _Kind.action,
  ),
  (
    time: '10.48',
    title: 'Dimas membuat rekam sesi',
    detail: '#0412 Andi Pratama · offline → tersinkron 10.52',
    kind: _Kind.action,
  ),
  (
    time: '10.41',
    title: 'Dimas melihat rontgen',
    detail: '#0412 Rontgen_lumbal.jpg',
    kind: _Kind.view,
  ),
  (
    time: '09.30',
    title: 'Sinta mengubah nomor HP',
    detail: '#0387 Rina Setiawati · 0812…4417 → 0813…9920',
    kind: _Kind.edit,
  ),
  (
    time: '08.05',
    title: 'Owner mengekspor laporan omzet',
    detail: 'Sep 2026 · tanpa data kontak',
    kind: _Kind.export,
  ),
  (
    time: '07.58',
    title: 'Login gagal 3× · laras.terapis',
    detail: 'Perangkat baru · Malang',
    kind: _Kind.security,
  ),
];

/// OW-18 Audit log (baca-saja): siapa melakukan apa, kapan, dari perangkat apa.
class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  _Filter _filter = _Filter.today;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final rows = _logs.where((l) {
      return switch (_filter) {
        _Filter.today || _Filter.all => true,
        _Filter.export => l.kind == _Kind.export,
        _Filter.edit => l.kind == _Kind.edit,
        _Filter.xray => l.kind == _Kind.view,
      };
    }).toList();

    return OlDetailScaffold(
      title: 'Audit log',
      context_: 'Baca-saja · tidak bisa dihapus',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (f, l) in const [
              (_Filter.today, 'Hari ini'),
              (_Filter.all, 'Semua staf'),
              (_Filter.export, 'Ekspor'),
              (_Filter.edit, 'Ubah data'),
              (_Filter.xray, 'Lihat rontgen'),
            ])
              OlChip(
                label: l,
                selected: _filter == f,
                onTap: () => setState(() => _filter = f),
              ),
          ],
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, l) in rows.indexed)
                Semantics(
                  container: true,
                  label: '${l.time}, ${l.title}. ${l.detail}',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: i < rows.length - 1
                          ? Border(bottom: BorderSide(color: c.line))
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 52,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              l.time,
                              style: t.mono.copyWith(fontSize: 13.5),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.title,
                                style: t.body.copyWith(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.detail,
                                style: t.body.copyWith(
                                  fontSize: 14,
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ?switch (l.kind) {
                          _Kind.view => const OlTag(
                            'Lihat',
                            tone: OlTagTone.muted,
                          ),
                          _Kind.edit => const OlTag(
                            'Ubah',
                            tone: OlTagTone.warn,
                          ),
                          _Kind.export => const OlTag('Ekspor'),
                          _Kind.security => const OlTag(
                            'Keamanan',
                            tone: OlTagTone.crit,
                          ),
                          _Kind.action => null,
                        },
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
