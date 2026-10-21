import 'dart:async';

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
import '../pasien_session.dart';
import 'slot_picker.dart';

typedef _Data = ({
  List<({String id, String name, String address})> branches,
  List<ServiceV> services,
  List<AddressV> addresses,
});

/// PS-08 Booking (tab Booking): layanan → keluhan → lokasi → waktu + ringkasan → terkirim, menunggu konfirmasi
/// front desk (§5.13). Bagian keluhan & data diri menggantikan formulir intake QR (WB-01) yang dihapus.
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
  final _complaint = TextEditingController();
  final _since = TextEditingController();
  String _sinceUnit = 'minggu';
  String? _cause;
  final _tb = TextEditingController();
  final _bb = TextEditingController();
  final _address = TextEditingController();
  final _job = TextEditingController();
  final _hobby = TextEditingController();
  String? _complaintError;
  bool _busy = false;

  static const _causes = [
    'Olahraga',
    'Jatuh',
    'Kerja / posisi duduk',
    'Kecelakaan',
    'Tidak tahu',
  ];
  static const _units = {
    'hari': 'Hari',
    'minggu': 'Minggu',
    'bulan': 'Bulan',
    'tahun': 'Tahun',
  };

  /// Catatan untuk front desk & terapis: keluhan + lama + penyebab + catatan bebas.
  String get _bookingNote => [
    'Keluhan: ${_complaint.text.trim()}',
    if (_since.text.trim().isNotEmpty)
      'sejak ${_since.text.trim()} $_sinceUnit',
    if (_cause != null) 'penyebab: ${_cause!.toLowerCase()}',
    if (_note.text.trim().isNotEmpty) 'Catatan: ${_note.text.trim()}',
  ].join(' · ');

  /// Isian data diri yang masih kosong di profil → disimpan sebelum booking dikirim.
  Map<String, dynamic> _profilePatch(Patient? p) {
    String? t(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return {
      if (p?.heightCm == null && int.tryParse(_tb.text) != null)
        'height_cm': int.parse(_tb.text),
      if (p?.weightKg == null &&
          double.tryParse(_bb.text.replaceAll(',', '.')) != null)
        'weight_kg': double.parse(_bb.text.replaceAll(',', '.')),
      if ((p?.address ?? '').isEmpty && t(_address) != null)
        'address': t(_address),
      if ((p?.institution ?? '').isEmpty && t(_job) != null)
        'occupation': t(_job),
      if ((p?.hobby ?? '').isEmpty && t(_hobby) != null) 'hobby': t(_hobby),
    };
  }

  @override
  void dispose() {
    for (final c in [
      _note,
      _complaint,
      _since,
      _tb,
      _bb,
      _address,
      _job,
      _hobby,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  PasienAppApi get _api => ref.read(pasienAppApiProvider);

  Future<_Data> _load() async {
    final branches = await _api.branches();
    final branch = _branchId ?? branches.firstOrNull?.id;
    final r = await (_api.catalog(branchId: branch), _api.addresses()).wait;
    return (branches: branches, services: r.$1.services, addresses: r.$2);
  }

  Future<void> _submit(String branchId) async {
    if (_complaint.text.trim().length < 3) {
      setState(() => _complaintError = 'Ceritakan singkat keluhan Anda.');
      return;
    }
    setState(() => _busy = true);
    final patch = _profilePatch(
      ref.read(pasienSessionProvider).account?.patient,
    );
    if (patch.isNotEmpty) {
      final saved = await runApi(
        context,
        () => _api.updateProfile(patch).then((_) => true),
      );
      if (!mounted) return;
      if (saved == null) return setState(() => _busy = false);
      unawaited(ref.read(pasienSessionProvider.notifier).refresh());
    }
    final b = await runApi(
      context,
      () => _api.book({
        'branch_id': branchId,
        'service_id': _serviceId,
        'location_type': _homeVisit ? 'home_visit' : 'clinic',
        'address_id': _homeVisit ? _addressId : null,
        'start': _start!.toUtc().toIso8601String(),
        'note': _bookingNote,
      }),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (b == null) return;
    final dpInvoice = b.$2;
    if (dpInvoice != null) {
      context.feedback.success(
        'Booking terkirim. Bayar DP agar jadwal diproses klinik.',
      );
      await context.push('${PRoutes.bayar}?invoice=$dpInvoice');
    } else {
      await context.feedback.sheet<void>(
        title: 'Booking terkirim',
        message:
            'Klinik akan mengonfirmasi jadwal Anda. Anda mendapat notifikasi saat dikonfirmasi.',
        actions: const [SheetAction('Oke', null)],
      );
    }
    if (!mounted) return;
    setState(() {
      _start = null;
      for (final c in [_note, _complaint, _since]) {
        c.clear();
      }
      _cause = null;
      _gen++;
    });
  }

  /// Data diri yang masih kosong di profil (dulu diisi di formulir intake QR) — cukup sekali.
  List<Widget> _dataDiri(BuildContext context) {
    final p = ref.watch(
      pasienSessionProvider.select((s) => s.account?.patient),
    );
    final needs = <Widget>[
      if (p?.heightCm == null || p?.weightKg == null)
        Row(
          children: [
            Expanded(
              child: OlTextField(
                label: 'Tinggi badan (cm)',
                controller: _tb,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: OlSpace.md),
            Expanded(
              child: OlTextField(
                label: 'Berat badan (kg)',
                controller: _bb,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      if ((p?.address ?? '').isEmpty)
        OlTextField(label: 'Alamat', controller: _address, maxLines: 2),
      if ((p?.institution ?? '').isEmpty)
        OlTextField(label: 'Pekerjaan / instansi', controller: _job),
      if ((p?.hobby ?? '').isEmpty)
        OlTextField(label: 'Hobi / olahraga', controller: _hobby),
    ];
    if (needs.isEmpty) return const [];
    return [
      const OlSectionHeader(title: 'Lengkapi data diri (sekali saja)'),
      OlCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, w) in needs.indexed) ...[
              if (i > 0) const SizedBox(height: OlSpace.md),
              w,
            ],
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => OlPageBody(
    header: OlAppHeader(
      title: 'Booking',
      actions: [
        OlIconButton(
          icon: OlIcons.calendar,
          semanticLabel: 'Jadwal saya',
          onPressed: () => context.push(PRoutes.jadwal),
        ),
      ],
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
            return const [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptySchedule,
                  title: 'Booking belum tersedia',
                  message:
                      'Hubungi klinik lewat WhatsApp untuk membuat jadwal.',
                ),
              ),
            ];
          }
          final services = [
            for (final s in d.services)
              if (s.isActive && (!_homeVisit || s.homeVisit)) s,
          ];
          final service = services.where((s) => s.id == _serviceId).firstOrNull;
          final canHomeVisit = d.services.any((s) => s.homeVisit);
          final ready =
              service != null &&
              _start != null &&
              (!_homeVisit || _addressId != null);
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
                  if (v && service != null && !service.homeVisit) {
                    _serviceId = null;
                  }
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
                      subtitle:
                          '${s.durationMin} mnt · ${Fmt.money(s.memberPrice ?? s.price)}',
                      trailing: s.id == _serviceId
                          ? OlIcon(OlIcons.checkCircle, color: c.brand)
                          : null,
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
                  child: Text(
                    'Tambah alamat dulu untuk home visit.',
                    style: t.bodyStrong.copyWith(color: c.brand),
                  ),
                )
              else
                OlSelectField<String?>(
                  label: 'Alamat home visit',
                  sheetTitle: 'Pilih alamat',
                  value: _addressId,
                  options: {
                    null: 'Pilih alamat',
                    for (final a in d.addresses)
                      a.id: '${a.label} · ${a.address}',
                  },
                  onChanged: (v) => setState(() => _addressId = v),
                ),
            ],
            if (service != null) ...[
              const OlSectionHeader(title: '2 · Keluhan'),
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OlTextField(
                      label: 'Apa yang Anda rasakan?',
                      isRequired: true,
                      controller: _complaint,
                      maxLines: 3,
                      hint: 'mis. nyeri punggung bawah saat membungkuk',
                      error: _complaintError,
                      onChanged: (_) => setState(() => _complaintError = null),
                    ),
                    const SizedBox(height: OlSpace.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 96,
                          child: OlTextField(
                            label: 'Sudah berapa lama?',
                            controller: _since,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: OlSpace.md),
                        Expanded(
                          child: OlSegmented<String>(
                            segments: _units,
                            value: _sinceUnit,
                            onChanged: (v) => setState(() => _sinceUnit = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: OlSpace.md),
                    Text('Penyebab', style: t.fieldLabel),
                    const SizedBox(height: OlSpace.sm),
                    Wrap(
                      spacing: OlSpace.sm,
                      runSpacing: OlSpace.sm,
                      children: [
                        for (final cs in _causes)
                          OlChip(
                            label: cs,
                            small: true,
                            selected: _cause == cs,
                            onTap: () => setState(
                              () => _cause = _cause == cs ? null : cs,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const OlSectionHeader(title: '3 · Waktu'),
              SlotPicker(
                branchId: branchId,
                serviceId: service.id,
                homeVisit: _homeVisit,
                value: _start,
                onChanged: (v) => setState(() => _start = v),
              ),
            ],
            if (ready) ...[
              ..._dataDiri(context),
              const OlSectionHeader(title: '4 · Ringkasan'),
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(service.name, style: t.heading),
                    Text(
                      '${Fmt.date(_start!.toLocal())} · ${Fmt.time(_start!.toLocal())}',
                      style: t.body,
                    ),
                    const SizedBox(height: OlSpace.sm),
                    OlMoneyRow(
                      label: 'Perkiraan biaya',
                      amount: service.memberPrice ?? service.price,
                    ),
                    const SizedBox(height: OlSpace.md),
                    OlTextField(
                      label: 'Catatan untuk klinik',
                      controller: _note,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              OlButton(
                label: 'Kirim booking',
                loading: _busy,
                onPressed: () => _submit(branchId),
              ),
              Text(
                'Biaya final dihitung di klinik sesuai tindakan.',
                style: t.caption.copyWith(color: c.muted),
              ),
            ],
          ];
        },
      ),
    ],
  );
}
