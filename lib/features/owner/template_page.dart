import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Msg { h1, struk, latihan, kontrol, linkBayar }

const _msgLabels = {
  _Msg.h1: 'Pengingat H-1',
  _Msg.struk: 'Struk pembayaran',
  _Msg.latihan: 'Program latihan',
  _Msg.kontrol: 'Ajak kontrol (>30 hari)',
  _Msg.linkBayar: 'Link bayar tagihan',
};

const _defaults = {
  _Msg.h1:
      'Halo {nama}, mengingatkan jadwal terapi Anda besok {tanggal} pukul {jam} di {cabang} bersama {terapis}. Balas 1 untuk konfirmasi, 2 untuk ubah jadwal.',
  _Msg.struk: 'Terima kasih {nama}. Struk pembayaran Anda di {cabang}: {link}',
  _Msg.latihan:
      'Halo {nama}, ini program latihan dari {terapis}. Lakukan sesuai jadwal ya: {link}',
  _Msg.kontrol:
      'Halo {nama}, sudah lebih dari sebulan sejak terapi terakhir. Yuk cek kondisi Anda di {cabang}: {link}',
  _Msg.linkBayar:
      'Halo {nama}, ada tagihan yang belum lunas di {cabang}. Bayar mudah lewat: {link}',
};

const _sample = {
  '{nama}': 'Rina',
  '{tanggal}': 'Kam, 8 Okt',
  '{jam}': '16.00',
  '{cabang}': 'Klinik Pusat Malang',
  '{terapis}': 'Dimas',
  '{link}': 'onelotus.id/b/x7k2',
};

/// OW-14 Template pesan WhatsApp: isi dengan variabel, pratinjau, dan
/// pintasan ke pengaturan lain.
class TemplatePage extends StatefulWidget {
  const TemplatePage({super.key});

  @override
  State<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage> {
  _Msg _msg = _Msg.h1;
  final _texts = Map.of(_defaults);
  late final _ctl = TextEditingController(text: _texts[_msg]);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _insert(String v) {
    final sel = _ctl.selection;
    final text = _ctl.text;
    final at = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    setState(() {
      _ctl.value = TextEditingValue(
        text: text.replaceRange(at, end, v),
        selection: TextSelection.collapsed(offset: at + v.length),
      );
      _texts[_msg] = _ctl.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    var preview = _ctl.text;
    _sample.forEach((k, v) => preview = preview.replaceAll(k, v));

    return OlDetailScaffold(
      title: 'Template',
      foot: [
        OlButton(
          label: 'Simpan template',
          onPressed: () => context.feedback.success(
            'Template "${_msgLabels[_msg]}" disimpan.',
          ),
        ),
      ],
      children: [
        OlSelectField<_Msg>(
          label: 'Pesan',
          sheetTitle: 'Pilih template',
          value: _msg,
          options: _msgLabels,
          onChanged: (v) => setState(() {
            _msg = v;
            _ctl.text = _texts[v]!;
          }),
        ),
        OlTextField(
          label: 'Isi pesan',
          controller: _ctl,
          maxLines: 4,
          onChanged: (v) => setState(() => _texts[_msg] = v),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final v in _sample.keys)
              Semantics(
                container: true,
                button: true,
                label: 'Sisipkan variabel ${v.replaceAll(RegExp(r'[{}]'), '')}',
                excludeSemantics: true,
                child: ActionChip(
                  label: Text(v, style: t.mono.copyWith(fontSize: 13.5)),
                  onPressed: () => _insert(v),
                  backgroundColor: c.surface,
                  side: BorderSide(color: c.line, width: 1.5),
                  shape: const StadiumBorder(),
                ),
              ),
          ],
        ),
        const OlOverline('PRATINJAU'),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F0EA),
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: 'Pratinjau pesan: $preview',
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(preview, style: t.body.copyWith(fontSize: 14.5)),
                  const SizedBox(height: 4),
                  Text(
                    '18.00',
                    style: t.body.copyWith(fontSize: 12.5, color: c.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        const OlOverline('KELOLA LAINNYA'),
        Wrap(
          spacing: 8,
          children: [
            for (final (l, r) in const [
              ('Aturan komisi', Routes.ownerAturanKomisi),
              ('Poin', Routes.ownerPoin),
              ('Pustaka latihan', Routes.ownerPustaka),
              ('Pengumuman', Routes.ownerPengumuman),
              ('Cabang', Routes.ownerCabang),
              ('Audit log', Routes.ownerAudit),
              ('Rekonsiliasi', Routes.ownerRekonsiliasi),
            ])
              OlChip(label: l, onTap: () => context.push(r)),
          ],
        ),
      ],
    );
  }
}
