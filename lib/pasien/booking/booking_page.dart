import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';
import 'slot_picker.dart';

typedef _Data = ({List<({String id, String name, String address})> branches, List<ServiceV> services, List<AddressV> addresses});

/// PS-08 Booking (tab Booking): layanan → lokasi → waktu + ringkasan → terkirim, menunggu konfirmasi front desk (§5.13).
/// Batas booking & DP diatur server dari `app_config` (TODO(workshop) §16 no. 11, 13, 18).
class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key});

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  int _gen = 0;
  String? _branchId, _serviceId, _addressId;
  bool _homeVisit = false;
  DateTime? _start;
  final _note = TextEditingController();
  bool _busy = false;

  PasienAppApi get _api => ref.read(pasienAppApiProvider);

  Future<_Data> _load() async {
    final branches = await _api.branches();
    final branch = _branchId ?? branches.firstOrNull?.id;
    final r = await (_api.catalog(branchId: branch), _api.addresses()).wait;
    return (branches: branches, services: r.$1.services, addresses: r.$2);
  }

  Future<void> _submit(String branchId) async {
    setState(() => _busy = true);
    final b = await runApi(
      context,
      () => _api.book({
        'branch_id': branchId,
        'service_id': _serviceId,
        'location_type': _homeVisit ? 'home_visit' : 'clinic',
        'address_id': _homeVisit ? _addressId : null,
        'start': _start!.toUtc().toIso8601String(),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      }),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (b == null) return;
    final dpInvoice = b.$2;
    if (dpInvoice != null) {
      context.feedback.success('Booking terkirim. Bayar DP agar jadwal diproses klinik.');
      await context.push('${PRoutes.bayar}?invoice=$dpInvoice');
    } else {
      await context.feedback.sheet<void>(
        title: 'Booking terkirim',
        message: 'Klinik akan mengonfirmasi jadwal Anda. Anda mendapat notifikasi saat dikonfirmasi.',
        actions: const [SheetAction('Oke', null)],
      );
    }
    if (!mounted) return;
    setState(() {
      _start = null;
      _note.clear();
      _gen++;
    });
  }

  @override
  Widget build(BuildContext context) => OlPageBody(
    header: OlAppHeader(
      title: 'Booking',
      actions: [OlIconButton(icon: OlIcons.calendar, semanticLabel: 'Jadwal saya', onPressed: () => context.push(PRoutes.jadwal))],
    ),
    children: [
      OlAsync<_Data>(
        key: ValueKey((_gen, _branchId)),
        load: _load,
        builder: (context, d, _) {
          final c = context.ol;
          final t = context.olText;
          final branchId = _branchId ?? d.branches.firstOrNull?.id;
          if (branchId == null || d.services.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptySchedule, title: 'Booking belum tersedia', message: 'Hubungi klinik lewat WhatsApp untuk membuat jadwal.'))];
          }
          final services = [for (final s in d.services) if (s.isActive && (!_homeVisit || s.homeVisit)) s];
          final service = services.where((s) => s.id == _serviceId).firstOrNull;
          final canHomeVisit = d.services.any((s) => s.homeVisit);
          final ready = service != null && _start != null && (!_homeVisit || _addressId != null);
          return [
            if (d.branches.length > 1)
              OlSelectField<String>(
                label: 'Cabang',
                sheetTitle: 'Pilih cabang',
                value: branchId,
                options: {for (final b in d.branches) b.id: b.name},
                onChanged: (v) => setState(() {
                  _branchId = v;
                  _serviceId = null;
                  _start = null;
                }),
              ),
            if (canHomeVisit)
              OlSegmented<bool>(
                segments: const {false: 'Di klinik', true: 'Home visit'},
                value: _homeVisit,
                onChanged: (v) => setState(() {
                  _homeVisit = v;
                  _start = null;
                  if (v && service != null && !service.homeVisit) _serviceId = null;
                }),
              ),
            const OlSectionHeader(title: '1 · Layanan'),
            OlCard(
              padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
              child: Column(
                children: [
                  for (final (n, s) in services.indexed)
                    OlListItem(
                      title: s.name,
                      subtitle: '${s.durationMin} mnt · ${Fmt.money(s.memberPrice ?? s.price)}',
                      trailing: s.id == _serviceId ? OlIcon(OlIcons.checkCircle, color: c.brand) : null,
                      divider: n < services.length - 1,
                      onTap: () => setState(() {
                        _serviceId = s.id;
                        _start = null;
                      }),
                    ),
                ],
              ),
            ),
            if (_homeVisit) ...[
              const OlSectionHeader(title: 'Alamat'),
              if (d.addresses.isEmpty)
                OlCard(
                  onTap: () async {
                    await context.push(PRoutes.alamat);
                    if (mounted) setState(() => _gen++);
                  },
                  child: Text('Tambah alamat dulu untuk home visit.', style: t.bodyStrong.copyWith(color: c.brand)),
                )
              else
                OlSelectField<String?>(
                  label: 'Alamat home visit',
                  sheetTitle: 'Pilih alamat',
                  value: _addressId,
                  options: {null: 'Pilih alamat', for (final a in d.addresses) a.id: '${a.label} · ${a.address}'},
                  onChanged: (v) => setState(() => _addressId = v),
                ),
            ],
            if (service != null) ...[
              const OlSectionHeader(title: '2 · Waktu'),
              SlotPicker(
                branchId: branchId,
                serviceId: service.id,
                homeVisit: _homeVisit,
                value: _start,
                onChanged: (v) => setState(() => _start = v),
              ),
            ],
            if (ready) ...[
              const OlSectionHeader(title: '3 · Ringkasan'),
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(service.name, style: t.heading),
                    Text('${Fmt.date(_start!.toLocal())} · ${Fmt.time(_start!.toLocal())}', style: t.body),
                    const SizedBox(height: OlSpace.sm),
                    OlMoneyRow(label: 'Perkiraan biaya', amount: service.memberPrice ?? service.price),
                    const SizedBox(height: OlSpace.md),
                    OlTextField(label: 'Catatan untuk klinik', controller: _note, maxLines: 2),
                  ],
                ),
              ),
              OlButton(label: 'Kirim booking', loading: _busy, onPressed: () => _submit(branchId)),
              Text('Biaya final dihitung di klinik sesuai tindakan.', style: t.caption.copyWith(color: c.muted)),
            ],
          ];
        },
      ),
    ],
  );
}
