import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'alamat_form_page.dart';

/// PS-19 Alamat home visit tersimpan. Tambah/ubah → [AlamatFormPage] (GPS, saran alamat dari peta, ketik manual).
/// Jangkauan home visit dihitung server dari radius cabang (OW-17).
class AlamatPage extends ConsumerStatefulWidget {
  const AlamatPage({super.key});

  @override
  ConsumerState<AlamatPage> createState() => _AlamatPageState();
}

class _AlamatPageState extends ConsumerState<AlamatPage> {
  int _gen = 0;

  PasienAppApi get _api => ref.read(pasienAppApiProvider);

  /// Form alamat (GPS + saran alamat dari peta + ketik manual) → daftar dimuat ulang.
  Future<void> _edit([AddressV? a]) async {
    final r = await Navigator.of(context).push<AddressV>(
      MaterialPageRoute(builder: (_) => AlamatFormPage(initial: a)),
    );
    if (r == null || !mounted) return;
    context.feedback.success(r.inArea ? 'Alamat disimpan.' : 'Alamat disimpan, tetapi di luar jangkauan home visit.');
    setState(() => _gen++);
  }

  Future<void> _delete(AddressV a) async {
    final ok = await context.feedback.confirm(ConfirmSpec(title: 'Hapus alamat ${a.label}?', message: a.address, confirmLabel: 'Hapus', danger: true));
    if (!ok || !mounted) return;
    final r = await runApi(context, () => _api.deleteAddress(a.id).then((_) => true));
    if (r == null || !mounted) return;
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    pinnedHeader: true,
    title: 'Alamat tersimpan',
    foot: [OlButton(label: 'Tambah alamat', icon: OlIcons.pin, onPressed: _edit)],
    children: [
      OlAsync<List<AddressV>>(
        key: ValueKey(_gen),
        load: _api.addresses,
        builder: (context, list, _) {
          final c = context.ol;
          final t = context.olText;
          if (list.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada alamat', message: 'Simpan alamat untuk booking home visit.'))];
          }
          return [
            for (final a in list)
              OlCard(
                onTap: () => _edit(a),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(a.label, style: t.heading),
                              if (a.isDefault) ...[const SizedBox(width: OlSpace.sm), const OlTag('Utama', tone: OlTagTone.brand)],
                              if (!a.inArea) ...[const SizedBox(width: OlSpace.sm), const OlTag('Di luar jangkauan', tone: OlTagTone.warn)],
                            ],
                          ),
                          Text(a.address, style: t.body.copyWith(color: c.muted)),
                          if (a.landmark != null) Text('Patokan: ${a.landmark}', style: t.caption.copyWith(color: c.muted)),
                        ],
                      ),
                    ),
                    OlIconButton(icon: OlIcons.close, semanticLabel: 'Hapus ${a.label}', onPressed: () => _delete(a)),
                  ],
                ),
              ),
          ];
        },
      ),
    ],
  );
}
