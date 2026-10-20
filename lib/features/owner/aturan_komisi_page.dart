import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'owner_forms.dart';

const _scopeLabels = {'service': 'Per layanan', 'extra_point': 'Titik tambahan', 'home_visit': 'Home visit'};

/// OW-11 Aturan komisi: komponen (persen/nominal), tanggal berlaku. Aturan baru tidak mengubah komisi lama.
/// Nilai komisi menunggu workshop mitra (§16 no. 2) — TODO(workshop); layar hanya menyimpan isian owner.
class AturanKomisiPage extends ConsumerStatefulWidget {
  const AturanKomisiPage({super.key});

  @override
  ConsumerState<AturanKomisiPage> createState() => _AturanKomisiPageState();
}

class _AturanKomisiPageState extends ConsumerState<AturanKomisiPage> {
  int _gen = 0;

  Future<(List<CommissionRuleV>, List<Service>, List<StaffMember>)> _load() {
    final branch = ref.read(authProvider).activeBranch;
    final api = ref.read(oneLotusApiProvider);
    return (
      ref.read(billingApiProvider).commissionRules(),
      branch == null ? Future.value(<Service>[]) : api.services(branch.id),
      api.staff(),
    ).wait;
  }

  Future<void> _edit(List<Service> services, List<StaffMember> staff, [CommissionRuleV? r]) async {
    var scope = r?.scope ?? 'service';
    var type = r?.type ?? 'percent';
    String? serviceId = r?.serviceId;
    String? staffId = r?.staffId;
    var from = r?.effectiveFrom ?? DateTime.now();
    final value = TextEditingController(text: r == null ? '' : '${r.value}');
    final ok = await formSheet(
      context,
      title: r == null ? 'Aturan baru' : 'Ubah aturan',
      message: 'Berlaku untuk sesi mulai tanggal berlaku. Komisi yang sudah tercatat tidak berubah.',
      fields: (set) => [
        OlSegmented<String>(segments: _scopeLabels, value: scope, onChanged: (v) => set(() => scope = v)),
        if (scope == 'service')
          OlSelectField<String?>(
            label: 'Layanan',
            sheetTitle: 'Pilih layanan',
            value: serviceId,
            options: {null: 'Semua layanan', for (final s in services) s.id: s.name},
            onChanged: (v) => set(() => serviceId = v),
          ),
        OlSelectField<String?>(
          label: 'Terapis',
          sheetTitle: 'Pilih terapis',
          value: staffId,
          options: {null: 'Semua terapis', for (final s in staff) if (s.user.roles.contains(Role.terapis)) s.user.id: s.user.name},
          onChanged: (v) => set(() => staffId = v),
        ),
        OlSegmented<String>(segments: const {'percent': 'Persen', 'amount': 'Nominal'}, value: type, onChanged: (v) => set(() => type = v)),
        OlTextField(label: type == 'percent' ? 'Komisi (%)' : 'Komisi (Rp)', controller: value, keyboardType: TextInputType.number, isRequired: true),
        OwDateRow(label: 'Berlaku mulai', value: from, onChanged: (d) => set(() => from = d)),
      ],
    );
    if (!ok || !mounted) return;
    final res = await runApi(
      context,
      () => ref.read(billingApiProvider).saveCommissionRule(r?.id, {
        'scope': scope,
        'type': type,
        'value': parseAmount(value.text),
        'service_id': scope == 'service' ? serviceId : null,
        'staff_id': staffId,
        'effective_from': isoDay(from),
      }),
    );
    if (res == null || !mounted) return;
    context.feedback.success('Aturan komisi disimpan.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlAsync<(List<CommissionRuleV>, List<Service>, List<StaffMember>)>(
    key: ValueKey(_gen),
    load: _load,
    builder: (context, d, _) {
      final (rules, services, staff) = d;
      final svc = {for (final s in services) s.id: s.name};
      final who = {for (final s in staff) s.user.id: s.user.name};
      return [
        const OwWorkshopNote('komisi'),
        if (rules.isEmpty)
          const OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada aturan', message: 'Tanpa aturan, komisi tercatat Rp0.'))
        else
          for (final scope in _scopeLabels.keys)
            if (rules.any((r) => r.scope == scope)) ...[
              OlSectionHeader(title: _scopeLabels[scope]!),
              OwListCard<CommissionRuleV>(
                items: [for (final r in rules) if (r.scope == scope) r],
                title: (r) => [
                  if (scope == 'service') r.serviceId == null ? 'Semua layanan' : svc[r.serviceId] ?? 'Layanan',
                  if (r.staffId != null) who[r.staffId] ?? 'Terapis',
                  if (scope != 'service' && r.staffId == null) 'Semua terapis',
                ].join(' · '),
                subtitle: (r) => 'Berlaku ${Fmt.dateNoDay(r.effectiveFrom)}',
                trailing: (r) => Text(r.type == 'percent' ? '${r.value}%' : Fmt.money(r.value), style: context.olText.bodyStrong),
                onTap: (r) => _edit(services, staff, r),
              ),
            ],
        const SizedBox(height: OlSpace.md),
        OlButton(label: 'Tambah aturan', icon: OlIcons.plus, onPressed: () => _edit(services, staff)),
      ];
    },
  ).asPage(context, 'Aturan komisi');
}
