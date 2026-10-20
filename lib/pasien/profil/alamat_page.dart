import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../features/owner/owner_widgets.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// PS-19 Alamat home visit tersimpan + tambah alamat (titik lokasi wajib, diambil dari GPS saat berada di alamat).
/// Jangkauan home visit dihitung server dari radius cabang (OW-17).
class AlamatPage extends ConsumerStatefulWidget {
  const AlamatPage({super.key});

  @override
  ConsumerState<AlamatPage> createState() => _AlamatPageState();
}

class _AlamatPageState extends ConsumerState<AlamatPage> {
  int _gen = 0;

  PasienAppApi get _api => ref.read(pasienAppApiProvider);

  Future<Position?> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) context.feedback.error(const AppError(ErrorCode.permLocation));
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
    } catch (_) {
      if (mounted) context.feedback.info('Lokasi belum didapat. Pastikan GPS aktif lalu coba lagi.');
      return null;
    }
  }

  Future<void> _edit([AddressV? a]) async {
    final label = TextEditingController(text: a?.label ?? 'Rumah');
    final address = TextEditingController(text: a?.address ?? '');
    final landmark = TextEditingController(text: a?.landmark ?? '');
    var isDefault = a?.isDefault ?? false;
    var useGps = a == null;
    final ok = await formSheet(
      context,
      title: a == null ? 'Tambah alamat' : 'Ubah alamat',
      message: a == null ? 'Simpan saat Anda berada di alamat ini agar titik lokasinya tepat.' : null,
      fields: (set) => [
        OlTextField(label: 'Nama alamat', controller: label, isRequired: true),
        OlTextField(label: 'Alamat lengkap', controller: address, maxLines: 3, isRequired: true),
        OlTextField(label: 'Patokan', controller: landmark),
        if (a != null) OwToggleRow(label: 'Perbarui titik lokasi dari posisi saya', value: useGps, onChanged: (v) => set(() => useGps = v)),
        OwToggleRow(label: 'Jadikan alamat utama', value: isDefault, onChanged: (v) => set(() => isDefault = v)),
      ],
    );
    if (!ok || !mounted) return;
    double? lat = a?.lat, lng = a?.lng;
    if (useGps) {
      final pos = await _locate();
      if (pos == null) return;
      lat = pos.latitude;
      lng = pos.longitude;
    }
    if (!mounted) return;
    final r = await runApi(
      context,
      () => _api.saveAddress(a?.id, {
        'label': label.text.trim(),
        'address': address.text.trim(),
        'landmark': landmark.text.trim().isEmpty ? null : landmark.text.trim(),
        'lat': lat,
        'lng': lng,
        'is_default': isDefault,
      }),
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
