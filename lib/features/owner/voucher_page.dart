import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'owner_forms.dart';
import 'owner_widgets.dart';

/// OW-12 Voucher & promo: daftar voucher + pemakaian, buat voucher baru. TODO(workshop) §16 no. 14.
class VoucherPage extends ConsumerStatefulWidget {
  const VoucherPage({super.key});

  @override
  ConsumerState<VoucherPage> createState() => _VoucherPageState();
}

class _VoucherPageState extends ConsumerState<VoucherPage> {
  int _gen = 0;

  Future<void> _edit([VoucherV? v]) async {
    final code = TextEditingController(text: v?.code ?? '');
    final value = TextEditingController(text: v == null ? '' : '${v.value}');
    final quota = TextEditingController(text: v?.quotaTotal?.toString() ?? '');
    final perPatient = TextEditingController(text: v?.quotaPerPatient?.toString() ?? '');
    var type = v?.type ?? 'percent';
    var min = v?.minAmount ?? 0;
    var starts = v?.startsAt ?? DateTime.now();
    var ends = v?.endsAt ?? DateTime.now().add(const Duration(days: 30));
    var active = v?.isActive ?? true;
    final ok = await formSheet(
      context,
      title: v == null ? 'Voucher baru' : 'Ubah voucher',
      fields: (set) => [
        OlTextField(label: 'Kode', controller: code, isRequired: true),
        OlSegmented<String>(segments: const {'percent': 'Persen', 'amount': 'Nominal'}, value: type, onChanged: (t) => set(() => type = t)),
        OlTextField(label: type == 'percent' ? 'Potongan (%)' : 'Potongan (Rp)', controller: value, keyboardType: TextInputType.number, isRequired: true),
        OlMoneyField(label: 'Minimal belanja', value: min, onChanged: (x) => set(() => min = x)),
        OlTextField(label: 'Kuota total (kosong = tanpa batas)', controller: quota, keyboardType: TextInputType.number),
        OlTextField(label: 'Maks per pasien (kosong = tanpa batas)', controller: perPatient, keyboardType: TextInputType.number),
        OwDateRow(label: 'Mulai', value: starts, onChanged: (d) => set(() => starts = d)),
        OwDateRow(label: 'Berakhir', value: ends, first: starts, onChanged: (d) => set(() => ends = d)),
        if (v != null) OwToggleRow(label: 'Aktif', value: active, onChanged: (x) => set(() => active = x)),
      ],
    );
    if (!ok || !mounted) return;
    int? n(TextEditingController c) => c.text.trim().isEmpty ? null : parseAmount(c.text);
    final r = await runApi(
      context,
      () => ref.read(billingApiProvider).saveVoucher(v?.id, {
        'code': code.text.trim().toUpperCase(),
        'type': type,
        'value': parseAmount(value.text),
        'min_amount': min,
        'quota_total': n(quota),
        'quota_per_patient': n(perPatient),
        'starts_at': DateTime(starts.year, starts.month, starts.day).toUtc().toIso8601String(),
        'ends_at': DateTime(ends.year, ends.month, ends.day, 23, 59, 59).toUtc().toIso8601String(),
        'is_active': active,
      }),
    );
    if (r == null || !mounted) return;
    context.feedback.success('Voucher disimpan.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Voucher & promo',
    foot: [OlButton(label: 'Buat voucher', icon: OlIcons.plus, onPressed: _edit)],
    children: [
      OlAsync<List<VoucherV>>(
        key: ValueKey(_gen),
        load: ref.read(billingApiProvider).vouchers,
        builder: (context, list, _) {
          final now = DateTime.now();
          return [
            if (list.isEmpty)
              const OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada voucher', message: 'Voucher dipakai kasir di rincian tagihan.'))
            else
              OwListCard<VoucherV>(
                items: list,
                title: (v) => '${v.code} · ${v.type == 'percent' ? '${v.value}%' : Fmt.money(v.value)}',
                subtitle: (v) => [
                  '${Fmt.dateNoDay(v.startsAt)} – ${Fmt.dateNoDay(v.endsAt)}',
                  '${v.useCount}${v.quotaTotal == null ? '' : '/${v.quotaTotal}'} dipakai',
                  if (v.useTotal > 0) Fmt.money(v.useTotal),
                ].join(' · '),
                trailing: (v) => !v.isActive
                    ? const OlTag('Nonaktif', tone: OlTagTone.muted)
                    : v.endsAt.isBefore(now)
                    ? const OlTag('Berakhir', tone: OlTagTone.strike)
                    : const OlTag('Aktif', tone: OlTagTone.ok),
                onTap: _edit,
              ),
          ];
        },
      ),
    ],
  );
}
