import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'owner_forms.dart';
import 'owner_widgets.dart';

/// Variabel yang diisi server saat mengirim WA.
const _vars = ['nama', 'tanggal', 'jam', 'terapis', 'cabang', 'tagihan', 'sisa', 'link'];

/// OW-14 Template pesan WhatsApp: isi dengan variabel `{nama}` dst., pratinjau, aktif/nonaktif.
class TemplatePage extends ConsumerStatefulWidget {
  const TemplatePage({super.key});

  @override
  ConsumerState<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends ConsumerState<TemplatePage> {
  int _gen = 0;

  Future<void> _edit([TemplateV? tpl]) async {
    final title = TextEditingController(text: tpl?.title ?? '');
    final key = TextEditingController(text: tpl?.key ?? '');
    final body = TextEditingController(text: tpl?.body ?? '');
    var active = tpl?.isActive ?? true;
    final ok = await formSheet(
      context,
      title: tpl == null ? 'Template baru' : tpl.title,
      message: 'Variabel: ${_vars.map((v) => '{$v}').join(' ')}',
      fields: (set) => [
        OlTextField(label: 'Judul', controller: title, isRequired: true),
        if (tpl == null) OlTextField(label: 'Kunci (mis. reminder_h1)', controller: key, isRequired: true),
        OlTextField(label: 'Isi pesan', controller: body, maxLines: 6, isRequired: true),
        OwToggleRow(label: 'Aktif', value: active, onChanged: (v) => set(() => active = v)),
      ],
    );
    if (!ok || !mounted) return;
    final r = await runApi(
      context,
      () => ref.read(billingApiProvider).saveTemplate(tpl?.id, {
        'kind': 'wa_message',
        'key': tpl?.key ?? key.text.trim(),
        'title': title.text.trim(),
        'content': {...?tpl?.content, 'body': body.text},
        'variables': [for (final v in _vars) if (body.text.contains('{$v}')) v],
        'is_active': active,
      }),
    );
    if (r == null || !mounted) return;
    context.feedback.success('Template disimpan.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Template pesan',
    foot: [OlButton.secondary(label: 'Template baru', icon: OlIcons.plus, onPressed: _edit)],
    children: [
      OlAsync<List<TemplateV>>(
        key: ValueKey(_gen),
        load: ref.read(billingApiProvider).templates,
        builder: (context, all, _) {
          final list = [for (final x in all) if (x.kind == 'wa_message') x];
          if (list.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada template', message: 'Template dipakai untuk pengingat, struk, dan tagihan via WhatsApp.'))];
          }
          return [
            OwListCard<TemplateV>(
              items: list,
              title: (x) => x.title,
              subtitle: (x) => x.body.replaceAll('\n', ' '),
              trailing: (x) => x.isActive ? null : const OlTag('Nonaktif', tone: OlTagTone.muted),
              onTap: _edit,
            ),
            Text('Pesan otomatis memakai template sesuai kuncinya.', style: context.olText.caption.copyWith(color: context.ol.muted)),
          ];
        },
      ),
    ],
  );
}
