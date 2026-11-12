import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const _banks = {
  'bca': 'BCA',
  'bni': 'BNI',
  'bri': 'BRI',
  'mandiri': 'Mandiri',
  'permata': 'Permata',
};

const _wallets = {
  'ovo': 'OVO',
  'dana': 'DANA',
  'shopeepay': 'ShopeePay',
};

/// PS-08 Booking (tab Booking):
/// - Booking Klinik (`location_type == 'clinic'`): Pilih layanan → keluhan → jadwal → pilih metode PG → langsung bayar (hit Tripay PG).
/// - Home Visit (`location_type == 'home_visit'`): Ajukan jadwal untuk dikonfirmasi admin klinik.
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

  // Pilihan Payment Gateway untuk Booking Klinik
  String _payMethod = 'qris';
  String _payBank = 'bca';
  String _payWallet = 'ovo';

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

  String get _payMethodLabel => switch (_payMethod) {
    'va' => 'Virtual Account ${_banks[_payBank] ?? _payBank.toUpperCase()}',
    'ewallet' => 'E-Wallet ${_wallets[_payWallet] ?? _payWallet.toUpperCase()}',
    _ => 'QRIS Instan',
  };

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
      setState(
        () => _complaintError = 'Ceritakan singkat keluhan yang Anda rasakan.',
      );
      context.feedback.info('Mohon isi keluhan Anda terlebih dahulu.');
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
    if (b == null) {
      setState(() => _busy = false);
      return;
    }

    final booking = b.$1;
    var invoiceId = b.$2;

    // Jika booking klinik dan invoice belum terbaca dari field dp_invoice,
    // cari tagihan payable terbaru milik pasien agar tetap bisa langsung bayar ke PG.
    if (!_homeVisit && invoiceId == null) {
      try {
        final invoices = await _api.invoices();
        final open = invoices
            .where((i) => i.payable && i.status != 'draft')
            .toList();
        invoiceId = open.firstOrNull?.id;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _busy = false);

    final chosenMethod = _payMethod;
    final chosenBank = _payBank;
    final chosenWallet = _payWallet;

    setState(() {
      _start = null;
      for (final c in [_note, _complaint, _since]) {
        c.clear();
      }
      _cause = null;
      _gen++;
    });

    if (invoiceId != null) {
      context.feedback.success(
        'Jadwal tercatat! Menghubungkan ke Payment Gateway...',
      );
      await context.push(
        '${PRoutes.bayar}?invoice=$invoiceId&method=$chosenMethod&bank=$chosenBank&wallet=$chosenWallet&autostart=1',
      );
    } else if (booking.status == 'accepted') {
      final goJadwal = await context.feedback.sheet<bool>(
        title: 'Jadwal terkonfirmasi',
        message:
            'Jadwal terapi Anda sudah terdaftar di klinik. Silakan datang tepat waktu.',
        actions: const [
          SheetAction('Lihat jadwal', true),
          SheetAction('Tutup', false),
        ],
      );
      if (goJadwal == true && mounted) {
        context.push(PRoutes.jadwal);
      }
    } else {
      await context.feedback.sheet<void>(
        title: 'Permintaan Home Visit Terkirim',
        message:
            'Klinik akan mengonfirmasi ketersediaan terapis & biaya transport ke alamat Anda.',
        actions: const [SheetAction('Mengerti', null)],
      );
    }
  }

  /// Data diri yang masih kosong di profil — cukup dilengkapi sekali.
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
        OlTextField(label: 'Alamat domisili', controller: _address, maxLines: 2),
      if ((p?.institution ?? '').isEmpty)
        OlTextField(label: 'Pekerjaan / instansi', controller: _job),
      if ((p?.hobby ?? '').isEmpty)
        OlTextField(label: 'Hobi / olahraga', controller: _hobby),
    ];
    if (needs.isEmpty) return const [];
    return [
      const _BookingStepHeader(
        title: 'Data Diri Tambahan',
        badge: OlTag('Sekali saja', tone: OlTagTone.brand),
      ),
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

  int _currentStep(ServiceV? service, bool ready) {
    if (ready) return 3;
    if (service != null && _complaint.text.trim().length >= 3) return 2;
    if (service != null) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) => OlPageBody(
    heroOverlap: true,
    header: OlAppHeader(
      hero: true,
      context_: _homeVisit
          ? 'Layanan Kunjungan ke Rumah'
          : 'Konfirmasi Instan · Pembayaran Online',
      title: 'Booking Terapi',
      actions: [
        OlIconButton(
          icon: OlIcons.calendar,
          semanticLabel: 'Jadwal saya',
          onHero: true,
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
          final branch =
              d.branches.where((b) => b.id == _branchId).firstOrNull ??
              d.branches.firstOrNull;
          final branchId = branch?.id;
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
          final step = _currentStep(service, ready);
          const stepLabels = [
            '1. Pilih Layanan',
            '2. Isi Keluhan',
            '3. Pilih Waktu',
            '4. Pembayaran',
          ];

          return [
            // Kartu Progres & Lokasi Klinik
            OlCard(
              padding: const EdgeInsets.all(OlSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c.brandSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: OlIcon(
                            _homeVisit ? OlIcons.homeVisit : OlIcons.branch,
                            color: c.brandDeep,
                            size: 20,
                            weight: OlIconWeight.duotone,
                          ),
                        ),
                      ),
                      const SizedBox(width: OlSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              branch?.name ?? 'Klinik One Lotus',
                              style: t.bodyStrong,
                            ),
                            if ((branch?.address ?? '').isNotEmpty)
                              Text(
                                branch!.address,
                                style: t.caption.copyWith(color: c.muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      OlTag(
                        stepLabels[step],
                        tone: ready ? OlTagTone.ok : OlTagTone.brand,
                      ),
                    ],
                  ),
                  const SizedBox(height: OlSpace.md),
                  OlStepProgress(count: 4, current: step),
                  if (d.branches.length > 1) ...[
                    const SizedBox(height: OlSpace.md),
                    OlSelectField<String>(
                      label: 'Pindah Cabang Klinik',
                      sheetTitle: 'Pilih cabang',
                      value: branchId,
                      options: {for (final b in d.branches) b.id: b.name},
                      onChanged: (v) => setState(() {
                        _branchId = v;
                        _serviceId = null;
                        _start = null;
                      }),
                    ),
                  ],
                ],
              ),
            ),

            // Pilihan Mode Kunjungan (Di Klinik vs Home Visit)
            if (canHomeVisit) ...[
              const OlSectionHeader(title: 'Mode Kunjungan'),
              OlTwoColumnGrid(
                children: [
                  OlOptionTile(
                    icon: OlIcons.branch,
                    label: 'Di Klinik',
                    subtitle: 'Langsung bayar & terjadwal',
                    selected: !_homeVisit,
                    onTap: () => setState(() {
                      _homeVisit = false;
                      _start = null;
                    }),
                  ),
                  OlOptionTile(
                    icon: OlIcons.homeVisit,
                    label: 'Home Visit',
                    subtitle: 'Terapis ke lokasi Anda',
                    selected: _homeVisit,
                    onTap: () => setState(() {
                      _homeVisit = true;
                      _start = null;
                      if (service != null && !service.homeVisit) {
                        _serviceId = null;
                      }
                    }),
                  ),
                ],
              ),
            ],

            // Alamat untuk Home Visit
            if (_homeVisit) ...[
              const OlSectionHeader(title: 'Lokasi Kunjungan'),
              if (d.addresses.isEmpty)
                OlCard(
                  onTap: () async {
                    await context.push(PRoutes.alamat);
                    if (mounted) setState(() => _gen++);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: c.brandSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: OlIcon(
                            OlIcons.pin,
                            color: c.brandDeep,
                            weight: OlIconWeight.duotone,
                          ),
                        ),
                      ),
                      const SizedBox(width: OlSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Belum ada alamat tersimpan',
                              style: t.bodyStrong,
                            ),
                            Text(
                              'Ketuk untuk menambahkan alamat home visit Anda',
                              style: t.caption.copyWith(color: c.brand),
                            ),
                          ],
                        ),
                      ),
                      OlIcon(OlIcons.chevronRight, color: c.muted),
                    ],
                  ),
                )
              else
                OlSelectField<String?>(
                  label: 'Pilih Alamat Home Visit',
                  sheetTitle: 'Pilih alamat kunjungan',
                  value: _addressId,
                  options: {
                    null: 'Pilih alamat...',
                    for (final a in d.addresses)
                      a.id: '${a.label} · ${a.address}',
                  },
                  onChanged: (v) => setState(() => _addressId = v),
                ),
            ],

            // 1. Pilih Layanan Terapi
            _BookingStepHeader(
              title: '1 · Pilih Layanan Terapi',
              badge: Text(
                '${services.length} layanan',
                style: t.caption.copyWith(color: c.muted),
              ),
            ),
            Column(
              children: [
                for (final (idx, s) in services.indexed) ...[
                  if (idx > 0) const SizedBox(height: OlSpace.sm),
                  _ServiceOptionCard(
                    service: s,
                    selected: s.id == _serviceId,
                    onTap: () => setState(() {
                      _serviceId = s.id;
                      _start = null;
                    }),
                  ),
                ],
              ],
            ),

            // 2. Keluhan & Kondisi
            if (service != null) ...[
              const _BookingStepHeader(
                title: '2 · Keluhan & Kondisi',
                badge: OlTag('Wajib', tone: OlTagTone.brand),
              ),
              OlCard(
                padding: const EdgeInsets.all(OlSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        OlIcon(
                          OlIcons.pain,
                          color: c.brand,
                          size: 18,
                          weight: OlIconWeight.duotone,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Informasi awal untuk terapis Anda',
                            style: t.caption.copyWith(
                              color: c.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: OlSpace.md),
                    OlTextField(
                      label: 'Apa keluhan utama yang Anda rasakan?',
                      isRequired: true,
                      controller: _complaint,
                      maxLines: 3,
                      hint:
                          'Contoh: Nyeri punggung bawah menjalar ke kaki saat membungkuk...',
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
                            hint: '2',
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
                    Text('Pemicu / Penyebab (opsional)', style: t.fieldLabel),
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

              // 3. Jadwal Terapi
              const OlSectionHeader(title: '3 · Pilih Jadwal Terapi'),
              SlotPicker(
                branchId: branchId,
                serviceId: service.id,
                homeVisit: _homeVisit,
                value: _start,
                onChanged: (v) => setState(() => _start = v),
              ),
            ],

            // 4. Pembayaran & Ringkasan Checkout
            if (ready) ...[
              ..._dataDiri(context),
              if (!_homeVisit) ...[
                const _BookingStepHeader(
                  title: '4 · Metode Pembayaran',
                  badge: OlTag(
                    'Payment Gateway',
                    tone: OlTagTone.ok,
                    icon: OlIcons.lock,
                  ),
                ),
                OlCard(
                  padding: const EdgeInsets.all(OlSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pilih kanal pembayaran instan',
                        style: t.caption.copyWith(color: c.muted),
                      ),
                      const SizedBox(height: OlSpace.md),
                      OlOptionTile(
                        icon: OlIcons.qris,
                        label: 'QRIS Instan',
                        subtitle:
                            'Scan QR dengan GoPay, OVO, DANA, ShopeePay, atau Mobile Banking',
                        selected: _payMethod == 'qris',
                        onTap: () => setState(() => _payMethod = 'qris'),
                      ),
                      const SizedBox(height: OlSpace.sm),
                      OlOptionTile(
                        icon: OlIcons.transfer,
                        label: 'Virtual Account Bank',
                        subtitle: 'BCA, BNI, BRI, Mandiri, Permata',
                        selected: _payMethod == 'va',
                        onTap: () => setState(() => _payMethod = 'va'),
                      ),
                      if (_payMethod == 'va') ...[
                        const SizedBox(height: OlSpace.sm),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Wrap(
                            spacing: OlSpace.sm,
                            runSpacing: OlSpace.sm,
                            children: [
                              for (final MapEntry(:key, :value)
                                  in _banks.entries)
                                OlChip(
                                  label: value,
                                  small: true,
                                  selected: _payBank == key,
                                  onTap: () => setState(() => _payBank = key),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: OlSpace.sm),
                      OlOptionTile(
                        icon: OlIcons.cash,
                        label: 'E-Wallet',
                        subtitle: 'OVO, DANA, ShopeePay',
                        selected: _payMethod == 'ewallet',
                        onTap: () => setState(() => _payMethod = 'ewallet'),
                      ),
                      if (_payMethod == 'ewallet') ...[
                        const SizedBox(height: OlSpace.sm),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Wrap(
                            spacing: OlSpace.sm,
                            runSpacing: OlSpace.sm,
                            children: [
                              for (final MapEntry(:key, :value)
                                  in _wallets.entries)
                                OlChip(
                                  label: value,
                                  small: true,
                                  selected: _payWallet == key,
                                  onTap: () => setState(() => _payWallet = key),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              OlSectionHeader(
                title: _homeVisit
                    ? '4 · Ringkasan Pengajuan'
                    : 'Ringkasan Booking & Tagihan',
              ),
              OlCard(
                padding: const EdgeInsets.all(OlSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c.brandSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: OlIcon(
                              OlIcons.hands,
                              color: c.brandDeep,
                              weight: OlIconWeight.duotone,
                            ),
                          ),
                        ),
                        const SizedBox(width: OlSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(service.name, style: t.heading),
                              const SizedBox(height: 2),
                              Text(
                                '${service.durationMin} menit · ${branch?.name ?? 'Klinik'}',
                                style: t.caption.copyWith(color: c.muted),
                              ),
                            ],
                          ),
                        ),
                        OlTag(
                          _homeVisit ? 'Home Visit' : 'Di Klinik',
                          tone: _homeVisit ? OlTagTone.gold : OlTagTone.brand,
                        ),
                      ],
                    ),
                    const SizedBox(height: OlSpace.md),
                    Container(
                      padding: const EdgeInsets.all(OlSpace.md),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _SummaryRow(
                            icon: OlIcons.calendar,
                            label: 'Tanggal',
                            value: Fmt.date(_start!.toLocal()),
                          ),
                          const SizedBox(height: 8),
                          _SummaryRow(
                            icon: OlIcons.clock,
                            label: 'Jam Terapi',
                            value: '${Fmt.time(_start!.toLocal())} WIB',
                          ),
                          if (!_homeVisit) ...[
                            const SizedBox(height: 8),
                            _SummaryRow(
                              icon: OlIcons.qris,
                              label: 'Pembayaran',
                              value: _payMethodLabel,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: OlSpace.md),
                    if (service.memberPrice != null &&
                        service.memberPrice! < service.price) ...[
                      OlMoneyRow(
                        label: 'Harga Normal',
                        amount: service.price,
                        muted: true,
                      ),
                      OlMoneyRow(
                        label: 'Harga Member',
                        amount: service.memberPrice!,
                      ),
                    ],
                    OlMoneyTotal(
                      label: _homeVisit
                          ? 'Estimasi Biaya Layanan'
                          : 'Total Pembayaran',
                      amount: service.memberPrice ?? service.price,
                    ),
                    const SizedBox(height: OlSpace.md),
                    OlTextField(
                      label: 'Catatan tambahan untuk klinik (opsional)',
                      controller: _note,
                      hint: 'Misal: preferensi terapis atau kondisi khusus...',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              OlButton(
                label: _homeVisit
                    ? 'Ajukan Jadwal Home Visit'
                    : 'Bayar & Konfirmasi · ${Fmt.money(service.memberPrice ?? service.price)}',
                icon: _homeVisit ? OlIcons.calendarPlus : OlIcons.lock,
                loading: _busy,
                onPressed: () => _submit(branchId),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OlIcon(
                    _homeVisit ? OlIcons.info : OlIcons.lock,
                    size: 14,
                    color: c.muted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _homeVisit
                          ? 'Biaya transport akan diinformasikan setelah jadwal dikonfirmasi.'
                          : 'Pembayaran diproses otomatis & aman melalui Payment Gateway.',
                      style: t.caption.copyWith(color: c.muted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ];
        },
      ),
    ],
  );
}

class _BookingStepHeader extends StatelessWidget {
  const _BookingStepHeader({required this.title, this.badge});

  final String title;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: t.heading.copyWith(fontSize: 17)),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: OlSpace.sm),
            badge!,
          ],
        ],
      ),
    );
  }
}

class _ServiceOptionCard extends StatelessWidget {
  const _ServiceOptionCard({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final ServiceV service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final effectivePrice = service.memberPrice ?? service.price;
    final hasMemberDiscount =
        service.memberPrice != null && service.memberPrice! < service.price;
    final radius = BorderRadius.circular(OlRadius.card);

    return AnimatedContainer(
      duration: OlMotion.of(context, OlMotion.fast),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: radius,
        border: Border.all(
          color: selected ? c.brand : c.line,
          width: selected ? 2.2 : 1,
        ),
        boxShadow: selected
            ? [BoxShadow(color: c.brandSoft, spreadRadius: 3)]
            : OlShadow.sh1,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(OlSpace.lg),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: selected ? c.brandDeep : c.brandSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: OlIcon(
                      OlIcons.hands,
                      size: 22,
                      color: selected ? Colors.white : c.brandDeep,
                      weight: OlIconWeight.duotone,
                    ),
                  ),
                ),
                const SizedBox(width: OlSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: t.bodyStrong.copyWith(fontSize: 15.5),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OlIcon(
                                OlIcons.clock,
                                size: 13.5,
                                color: c.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${service.durationMin} menit',
                                style: t.caption.copyWith(
                                  color: c.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (service.homeVisit)
                            const OlTag(
                              'Tersedia Home Visit',
                              tone: OlTagTone.muted,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: OlSpace.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.money(effectivePrice),
                      style: t.mono.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: selected ? c.brandDeep : c.fg,
                      ),
                    ),
                    if (hasMemberDiscount)
                      Text(
                        Fmt.money(service.price),
                        style: t.caption.copyWith(
                          fontSize: 11.5,
                          color: c.faint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: selected ? c.brand : c.faint,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final OlIconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Row(
      children: [
        OlIcon(icon, size: 16, color: c.muted),
        const SizedBox(width: 8),
        Text(label, style: t.caption.copyWith(color: c.muted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: t.caption.copyWith(
              color: c.fg,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
