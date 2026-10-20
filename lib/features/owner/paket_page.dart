import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'owner_forms.dart';
import 'owner_widgets.dart';

/// OW-10 Paket & membership. Perubahan tidak memengaruhi paket yang sudah terjual.
/// Aturan kuota/kedaluwarsa paket menunggu workshop mitra (spec §16) — hanya isian. TODO(workshop)
class PaketPage extends ConsumerStatefulWidget {
  const PaketPage({super.key});

  @override
  ConsumerState<PaketPage> createState() => _PaketPageState();
}

class _PaketPageState extends ConsumerState<PaketPage> {
  int _gen = 0;

  Future<void> _edit([PackageV? p]) async {
    final name = TextEditingController(text: p?.name ?? '');
    final count = TextEditingController(text: p == null ? '' : '${p.sessionCount}');
    final days = TextEditingController(text: p == null ? '' : '${p.validDays}');
    var price = p?.price ?? 0;
    var active = p?.isActive ?? true;
    final ok = await formSheet(
      context,
      title: p == null ? 'Paket baru' : 'Ubah paket',
      message: 'Paket yang sudah terjual tetap memakai ketentuan lama.',
      fields: (set) => [
        OlTextField(label: 'Nama paket', controller: name, isRequired: true),
        OlTextField(label: 'Jumlah sesi', controller: count, keyboardType: TextInputType.number, isRequired: true),
        OlTextField(label: 'Berlaku (hari)', controller: days, keyboardType: TextInputType.number, isRequired: true),
        OlMoneyField(label: 'Harga', value: price, onChanged: (v) => set(() => price = v)),
        if (p != null) OwToggleRow(label: 'Aktif dijual', value: active, onChanged: (v) => set(() => active = v)),
      ],
    );
    if (!ok || !mounted) return;
    final r = await runApi(
      context,
      () => ref.read(billingApiProvider).savePackage(p?.id, {
        'name': name.text.trim(),
        'session_count': parseAmount(count.text),
        'valid_days': parseAmount(days.text),
        'price': price,
        'is_active': active,
        if (p != null) 'service_ids': p.serviceIds,
        if (p != null) 'branch_ids': p.branchIds,
      }),
    );
    if (r == null || !mounted) return;
    context.feedback.success('Paket disimpan.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Paket & membership',
    foot: [OlButton(label: 'Tambah paket', icon: OlIcons.plus, onPressed: _edit)],
    children: [
      const OwWorkshopNote('kuota & masa berlaku paket'),
      OlAsync<List<PackageV>>(
        key: ValueKey(_gen),
        load: ref.read(billingApiProvider).packages,
        builder: (context, list, _) => [
          if (list.isEmpty)
            const OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada paket', message: 'Tambah paket untuk dijual kasir dan dibeli pasien.'))
          else
            OwListCard<PackageV>(
              items: list,
              title: (p) => p.name,
              subtitle: (p) => [
                '${p.sessionCount} sesi',
                '${p.validDays} hari',
                if (p.savings > 0) 'hemat ${Fmt.money(p.savings)}',
                if (!p.isActive) 'nonaktif',
              ].join(' · '),
              trailing: (p) => Text(Fmt.money(p.price), style: context.olText.bodyStrong),
              onTap: _edit,
            ),
        ],
      ),
    ],
  );
}
