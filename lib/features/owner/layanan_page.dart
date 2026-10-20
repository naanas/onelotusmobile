import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'owner_forms.dart';
import 'owner_widgets.dart';

/// OW-09 Layanan & harga: ubah harga, harga member, biaya per titik, tambahan cedera, home visit.
/// Harga baru berlaku untuk tagihan berikutnya; tagihan lama memakai harga saat sesi.
class LayananPage extends ConsumerStatefulWidget {
  const LayananPage({super.key});

  @override
  ConsumerState<LayananPage> createState() => _LayananPageState();
}

class _LayananPageState extends ConsumerState<LayananPage> {
  int _gen = 0;

  Future<void> _edit([ServiceV? s]) async {
    final name = TextEditingController(text: s?.name ?? '');
    final duration = TextEditingController(text: s == null ? '60' : '${s.durationMin}');
    final category = TextEditingController(text: s?.category ?? '');
    var price = s?.price ?? 0;
    var member = s?.memberPrice ?? 0;
    var perPoint = s?.perExtraPoint ?? 0;
    var injury = s?.injurySurcharge ?? 0;
    var homeVisit = s?.homeVisit ?? false;
    var active = s?.isActive ?? true;
    final ok = await formSheet(
      context,
      title: s == null ? 'Layanan baru' : 'Ubah layanan',
      message: 'Harga baru berlaku untuk tagihan berikutnya.',
      fields: (set) => [
        OlTextField(label: 'Nama layanan', controller: name, isRequired: true),
        OlTextField(label: 'Durasi (menit)', controller: duration, keyboardType: TextInputType.number, isRequired: true),
        OlTextField(label: 'Kategori', controller: category),
        OlMoneyField(label: 'Harga', value: price, onChanged: (v) => set(() => price = v)),
        OlMoneyField(label: 'Harga member (0 = sama)', value: member, onChanged: (v) => set(() => member = v)),
        OlMoneyField(label: 'Per titik tambahan', value: perPoint, onChanged: (v) => set(() => perPoint = v)),
        OlMoneyField(label: 'Tambahan cedera', value: injury, onChanged: (v) => set(() => injury = v)),
        OwToggleRow(label: 'Bisa home visit', value: homeVisit, onChanged: (v) => set(() => homeVisit = v)),
        if (s != null) OwToggleRow(label: 'Aktif', value: active, onChanged: (v) => set(() => active = v)),
      ],
    );
    if (!ok || !mounted) return;
    final branch = ref.read(authProvider).activeBranch;
    final r = await runApi(
      context,
      () => ref.read(billingApiProvider).saveService(s?.id, {
        'name': name.text.trim(),
        'duration_min': parseAmount(duration.text),
        'category': category.text.trim().isEmpty ? null : category.text.trim(),
        'price': price,
        'member_price': member == 0 ? null : member,
        'price_per_extra_point': perPoint,
        'injury_surcharge': injury,
        'home_visit_allowed': homeVisit,
        'is_active': active,
        'version': ?s?.version,
        'branch_ids': s?.branchIds ?? [?branch?.id],
      }),
    );
    if (r == null || !mounted) return;
    context.feedback.success('Layanan disimpan.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(authProvider.select((a) => a.activeBranch));
    return OlDetailScaffold(
      title: 'Layanan & harga',
      context_: branch?.name,
      foot: [OlButton.secondary(label: 'Tambah layanan', icon: OlIcons.plus, onPressed: _edit)],
      children: [
        OlAsync<List<ServiceV>>(
          key: ValueKey(_gen),
          load: ref.read(billingApiProvider).catalogServices,
          builder: (context, list, _) => [
            if (list.isEmpty)
              const OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada layanan', message: 'Tambah layanan agar bisa dijadwalkan.'))
            else
              OwListCard<ServiceV>(
                items: list,
                title: (s) => s.name,
                subtitle: (s) => [
                  '${s.durationMin} mnt',
                  if (s.memberPrice != null) 'member ${Fmt.money(s.memberPrice!)}',
                  if (s.homeVisit) 'home visit',
                  if (!s.isActive) 'nonaktif',
                ].join(' · '),
                trailing: (s) => Text(Fmt.money(s.price), style: context.olText.mono.copyWith(fontWeight: FontWeight.w700)),
                onTap: _edit,
              ),
          ],
        ),
      ],
    );
  }
}
