import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/pasien/pasien_app_api.dart';
import '../../features/common/billing_common.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';
import '../pasien_session.dart';
import 'booking_request_card.dart';
import 'rontgen_picker.dart';
import 'payment_channel_picker.dart';
import 'slot_picker.dart';

typedef _Data = ({
  List<({String id, String name, String address})> branches,
  List<ServiceV> services,
  List<AddressV> addresses,
});

/// PS-08 Booking (tab Booking) — wizard 4 langkah, satu langkah per layar, tombol melekat di bawah:
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

  /// Tipe kunjungan sudah dipilih di langkah pertama.
  bool _typeChosen = false;
  DateTime? _start;

  // Kanal bayar (Dupay) untuk Booking Klinik; biaya admin dihitung ulang tiap ganti kanal.
  PayChannelV? _channel;

  /// Perkiraan biaya home visit (layanan + transport menurut jarak), dimuat ulang bila cabang/layanan/alamat berubah.
  Future<HomeVisitEstimateV>? _estimate;

  /// Alamat tersimpan pasien (dari data katalog) — untuk ringkasan pengajuan.
  List<AddressV> _addresses = const [];
  String? get _addressText {
    final a = _addresses.where((a) => a.id == _addressId).firstOrNull;
    return a == null ? null : [a.address, if (a.landmark?.isNotEmpty ?? false) a.landmark!].join(' · ');
  }
  String? _estimateKey;
  HomeVisitEstimateV? _estimateValue;

  Future<HomeVisitEstimateV>? _estimateFor(String branchId, String serviceId) {
    final addr = _addressId;
    if (!_homeVisit || addr == null) return null;
    final key = '$branchId|$serviceId|$addr';
    if (key != _estimateKey) {
      _estimateKey = key;
      _estimateValue = null;
      _estimate = _api.homeVisitEstimate(branchId: branchId, serviceId: serviceId, addressId: addr)
        ..then((e) {
          if (mounted && _estimateKey == key) setState(() => _estimateValue = e);
        }, onError: (_) {}).ignore();
    }
    return _estimate;
  }
  bool _feeBusy = false;

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
  late final _xray = RontgenController(() => _api);

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

  String get _payMethodLabel => _channel?.label ?? '-';

  /// Total dibayar pasien: harga layanan + biaya admin kanal.
  int _total(ServiceV service) =>
      (service.memberPrice ?? service.price) + (_homeVisit ? 0 : _channel?.fee ?? 0);

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
    _scroll.dispose();
    _xray.dispose();
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
    if (_xray.uploading) {
      context.feedback.info('Tunggu sampai foto rontgen selesai diunggah.');
      return;
    }
    if (_complaint.text.trim().length < 3) {
      setState(
        () => _complaintError = 'Ceritakan singkat keluhan yang Anda rasakan.',
      );
      context.feedback.info('Mohon isi keluhan Anda terlebih dahulu.');
      _goTo(2);
      return;
    }
    // Klinik: langsung pindah ke layar bayar; booking + tagihan dibuat di sana (animasi memuat).
    if (!_homeVisit) return _submitClinic(branchId);
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
    await _attachXray(booking.id);
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

    final chosenMethod = _channel?.method ?? 'qris';
    final chosenBank = _channel?.vaBank ?? '';
    final chosenWallet = _channel?.ewallet ?? '';

    setState(() {
      _start = null;
      for (final c in [_note, _complaint, _since]) {
        c.clear();
      }
      _cause = null;
      _step = 0;
      _gen++;
      _xray.clear();
    });

    if (invoiceId != null) {
      context.feedback.success(
        'Jadwal tercatat! Menyiapkan pembayaran...',
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

  /// Rontgen yang sudah diunggah → kaitkan ke booking. Gagal tidak membatalkan booking (bisa dikirim ulang ke klinik).
  Future<void> _attachXray(String bookingId) async {
    final ids = _xray.ids;
    if (ids.isEmpty) return;
    try {
      await _api.attachIntake(bookingId, ids);
    } catch (_) {
      if (mounted) context.feedback.info('Booking tercatat, tapi foto rontgen gagal dikirim. Tunjukkan langsung di klinik.');
    }
  }

  /// Booking klinik: simpan data diri (bila perlu) → buat booking → cari tagihan DP.
  /// Melempar error (ditampilkan layar bayar); mengembalikan id tagihan atau null (tanpa tagihan).
  Future<String?> _createClinicBooking(String branchId) async {
    final patch = _profilePatch(ref.read(pasienSessionProvider).account?.patient);
    if (patch.isNotEmpty) {
      await _api.updateProfile(patch);
      unawaited(ref.read(pasienSessionProvider.notifier).refresh());
    }
    final b = await _api.book({
      'branch_id': branchId,
      'service_id': _serviceId,
      'location_type': 'clinic',
      'address_id': null,
      'start': _start!.toUtc().toIso8601String(),
      'note': _bookingNote,
    });
    await _attachXray(b.$1.id);
    var invoiceId = b.$2;
    // Tagihan belum terbaca dari dp_invoice → ambil tagihan terbuka terbaru.
    if (invoiceId == null) {
      try {
        final open = (await _api.invoices()).where((i) => i.payable && i.status != 'draft');
        invoiceId = open.firstOrNull?.id;
      } catch (_) {}
    }
    return invoiceId;
  }

  void _resetForm() => setState(() {
    _start = null;
    for (final c in [_note, _complaint, _since]) {
      c.clear();
    }
    _cause = null;
    _step = 0;
    _typeChosen = false;
    _gen++;
    _xray.clear();
  });

  /// Geser bayar → layar bayar terbuka seketika; proses booking berjalan di sana.
  void _submitClinic(String branchId) {
    final ch = _channel;
    final prepared = _createClinicBooking(branchId);
    // Form dikosongkan hanya bila booking berhasil (gagal → kembali dengan isian utuh).
    prepared.then((_) {
      if (mounted) _resetForm();
    }, onError: (_) {});
    context.push(
      '${PRoutes.bayar}?method=${ch?.method ?? 'qris'}&bank=${ch?.vaBank ?? ''}&wallet=${ch?.ewallet ?? ''}&autostart=1',
      extra: prepared,
    );
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

  // ── wizard: satu langkah per layar, tombol Lanjut/Kembali melekat di bawah ──

  List<String> get _stepTitles => ['Tipe', 'Layanan', 'Keluhan', 'Jadwal', _homeVisit ? 'Ajukan' : 'Bayar'];
  static const _steps = 5;

  /// Langkah aktif (0 tipe kunjungan · 1 layanan · 2 keluhan · 3 jadwal · 4 konfirmasi & bayar/ajukan).
  int _step = 0;
  final _scroll = ScrollController();

  /// Data katalog terakhir dari [OlAsync] — dipakai tombol bawah (di luar daftar).
  _Data? _data;

  ({
    ({String id, String name, String address})? branch,
    List<ServiceV> services,
    ServiceV? service,
    bool canHomeVisit,
  })
  _derive(_Data d) {
    final branch =
        d.branches.where((b) => b.id == _branchId).firstOrNull ??
        d.branches.firstOrNull;
    final services = [
      for (final s in d.services)
        if (s.isActive && (!_homeVisit || s.homeVisit)) s,
    ];
    return (
      branch: branch,
      services: services,
      service: services.where((s) => s.id == _serviceId).firstOrNull,
      canHomeVisit: d.services.any((s) => s.homeVisit),
    );
  }

  bool _stepDone(int i, ServiceV? service) => switch (i) {
    0 => _typeChosen && (!_homeVisit || _addressId != null),
    1 => service != null,
    2 => _complaint.text.trim().length >= 3,
    3 => _start != null,
    _ => false,
  };

  /// Langkah terjauh yang boleh dibuka (semua langkah sebelumnya sudah lengkap).
  int _maxStep(ServiceV? service) {
    var i = 0;
    while (i < _steps - 1 && _stepDone(i, service)) {
      i++;
    }
    return i;
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _step = step);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: OlMotion.of(context, OlMotion.slow),
        curve: OlMotion.curve,
      );
    }
  }

  void _next(ServiceV? service) {
    if (_step == 2 && !_stepDone(2, service)) {
      setState(
        () => _complaintError = 'Ceritakan singkat keluhan yang Anda rasakan.',
      );
      return;
    }
    if (_stepDone(_step, service)) _goTo(_step + 1);
  }

  @override
  Widget build(BuildContext context) => OlPageBody(
    pinnedHeader: true,
    heroOverlap: true,
    controller: _scroll,
    header: OlAppHeader(
      hero: true,
      context_: !_typeChosen
          ? 'One Lotus Personal Therapy'
          : _homeVisit
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
    foot: _foot(context),
    children: [
      OlAsync<_Data>(
        key: ValueKey((_gen, _branchId)),
        load: _load,
        builder: (context, d, _) {
          if (!identical(_data, d)) {
            _data = d;
            // Tombol bawah ada di luar OlAsync: bangun ulang halaman setelah data tiba.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
          final x = _derive(d);
          if (x.branch == null || d.services.isEmpty) {
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
          return [
            _progressCard(context, d, x.branch!, x.service),
            ...switch (_step) {
              0 => _stepType(context, d, x.branch!, x.service, x.canHomeVisit),
              1 => _stepService(context, x.services),
              2 => _stepComplaint(context),
              3 => _stepSchedule(x.branch!.id, x.service!),
              _ => _stepConfirm(context, x.branch!, x.service!),
            },
          ];
        },
      ),
    ],
  );

  /// Tombol melekat: ringkasan pilihan + Kembali / Lanjut (atau Bayar di langkah terakhir).
  Widget? _foot(BuildContext context) {
    final d = _data;
    if (d == null) return null;
    final x = _derive(d);
    if (x.branch == null || d.services.isEmpty) return null;
    final c = context.ol;
    final t = context.olText;
    final service = x.service;
    final price = service == null ? null : service.memberPrice ?? service.price;

    final Widget primary = switch (_step) {
      4 when _homeVisit => OlButton(
        label: 'Ajukan Home Visit',
        icon: OlIcons.calendarPlus,
        loading: _busy,
        // Di luar jangkauan cabang → tidak bisa diajukan (klinik pasti menolak).
        onPressed: _estimateValue?.inArea == false ? null : () => _submit(x.branch!.id),
      ),
      // Aksi uang: geser untuk bayar (bukan ketuk) agar tidak terbayar tanpa sengaja.
      4 => OlSlideToConfirm(
        label: 'Geser untuk bayar ${Fmt.money(_total(service!))}',
        loading: _busy,
        onConfirmed: _channel == null || _feeBusy
            ? null
            : () => _submit(x.branch!.id),
      ),
      _ => OlButton(
        label: 'Lanjut · ${_stepTitles[_step + 1]}',
        // Langkah keluhan selalu bisa diketuk agar pesan wajib isi muncul.
        onPressed: _step == 2 || _stepDone(_step, service)
            ? () => _next(service)
            : null,
      ),
    };

    return OlFootBar(
      children: [
        if (service != null && _step < 4)
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    service.name,
                    if (_start != null)
                      '${Fmt.dateNoDay(_start!.toLocal())} ${Fmt.time(_start!.toLocal())}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: c.muted),
                ),
              ),
              const SizedBox(width: OlSpace.sm),
              Text(
                Fmt.money(price!),
                style: t.bodyStrong.copyWith(color: c.brandDeep),
              ),
            ],
          ),
        Row(
          children: [
            if (_step == 4 && !_homeVisit) ...[
              // Ruang untuk geser: kembali cukup ikon.
              OlIconButton(
                icon: OlIcons.back,
                semanticLabel: 'Kembali',
                onPressed: _busy ? null : () => _goTo(_step - 1),
              ),
              const SizedBox(width: OlSpace.xs),
            ] else if (_step > 0) ...[
              OlButton.secondary(
                label: 'Kembali',
                expand: false,
                onPressed: _busy ? null : () => _goTo(_step - 1),
              ),
              const SizedBox(width: OlSpace.sm),
            ],
            Expanded(child: primary),
          ],
        ),
      ],
    );
  }

  /// Kartu atas: cabang + penanda langkah (langkah yang sudah lengkap bisa diketuk).
  Widget _progressCard(
    BuildContext context,
    _Data d,
    ({String id, String name, String address}) branch,
    ServiceV? service,
  ) {
    final c = context.ol;
    final t = context.olText;
    final maxStep = _maxStep(service);
    return OlCard(
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
                    Text(branch.name, style: t.bodyStrong),
                    if (branch.address.isNotEmpty)
                      Text(
                        branch.address,
                        style: t.caption.copyWith(color: c.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              OlTag('Langkah ${_step + 1}/$_steps', tone: OlTagTone.brand),
            ],
          ),
          const SizedBox(height: OlSpace.md),
          OlStepper(
            current: _step,
            maxReachable: maxStep,
            onTap: _goTo,
            steps: [
              OlStep('Tipe', _homeVisit ? OlIcons.homeVisit : OlIcons.branch),
              const OlStep('Layanan', OlIcons.hands),
              const OlStep('Keluhan', OlIcons.pain),
              const OlStep('Jadwal', OlIcons.calendar),
              OlStep(_stepTitles[4], _homeVisit ? OlIcons.send : OlIcons.cash),
            ],
          ),
          if (_step == 0 && d.branches.length > 1) ...[
            const SizedBox(height: OlSpace.md),
            OlSelectField<String>(
              label: 'Pindah Cabang Klinik',
              sheetTitle: 'Pilih cabang',
              value: branch.id,
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
    );
  }

  /// Langkah 1: tipe kunjungan — datang ke klinik atau home visit (+ alamat).
  List<Widget> _stepType(
    BuildContext context,
    _Data d,
    ({String id, String name, String address}) branch,
    ServiceV? service,
    bool canHomeVisit,
  ) {
    final c = context.ol;
    final t = context.olText;
    _addresses = d.addresses; // untuk ringkasan pengajuan (alamat terpilih)
    return [
      const _BookingStepHeader(title: 'Mau terapi di mana?'),
      _VisitTypeCard(
        icon: OlIcons.branch,
        title: 'Datang ke klinik',
        subtitle: branch.address.isEmpty ? branch.name : '${branch.name} · ${branch.address}',
        points: const ['Jadwal langsung terkonfirmasi', 'Bayar online saat booking'],
        selected: _typeChosen && !_homeVisit,
        onTap: () {
          setState(() {
            if (_homeVisit) _start = null;
            _homeVisit = false;
            _typeChosen = true;
          });
          // Klinik tidak butuh isian lain → lanjut otomatis ke layanan.
          Future.delayed(const Duration(milliseconds: 280), () {
            if (mounted && _step == 0) _goTo(1);
          });
        },
      ),
      _VisitTypeCard(
        icon: OlIcons.homeVisit,
        title: 'Home Visit',
        subtitle: canHomeVisit
            ? 'Terapis datang ke rumah Anda'
            : 'Belum tersedia di cabang ini',
        points: const ['Jadwal dikonfirmasi admin klinik', 'Biaya transport diinformasikan setelahnya'],
        selected: _typeChosen && _homeVisit,
        onTap: canHomeVisit
            ? () => setState(() {
                if (!_homeVisit) _start = null;
                _homeVisit = true;
                _typeChosen = true;
                if (service != null && !service.homeVisit) _serviceId = null;
                // Satu alamat tersimpan → langsung dipakai.
                if (_addressId == null && d.addresses.length == 1) _addressId = d.addresses.first.id;
                _addresses = d.addresses;
              })
            : null,
      ),
      if (_typeChosen && _homeVisit) ...[
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
                      Text('Belum ada alamat tersimpan', style: t.bodyStrong),
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
              for (final a in d.addresses) a.id: '${a.label} · ${a.address}',
            },
            onChanged: (v) => setState(() {
              _addressId = v;
              _addresses = d.addresses;
            }),
          ),
      ],
      if (!canHomeVisit)
        Text(
          'Layanan home visit belum dibuka. Silakan datang ke klinik.',
          style: t.caption.copyWith(color: c.muted),
        ),
    ];
  }

  /// Langkah 2: pilih layanan (disaring sesuai tipe kunjungan).
  List<Widget> _stepService(BuildContext context, List<ServiceV> services) {
    final c = context.ol;
    final t = context.olText;
    return [
      _BookingStepHeader(
        title: 'Pilih Layanan Terapi',
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
              onTap: () {
                setState(() {
                  if (_serviceId != s.id) _start = null;
                  _serviceId = s.id;
                });
                // Pilihan layanan menyelesaikan langkah ini → lanjut otomatis.
                Future.delayed(const Duration(milliseconds: 280), () {
                  if (mounted && _step == 1) _goTo(2);
                });
              },
            ),
          ],
        ],
      ),
    ];
  }

  /// Langkah 2: keluhan & kondisi.
  List<Widget> _stepComplaint(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return [
      const _BookingStepHeader(
        title: 'Keluhan & Kondisi',
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
            _DurationField(
              controller: _since,
              unit: _sinceUnit,
              units: _units,
              onUnitChanged: (v) => setState(() => _sinceUnit = v),
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
                    onTap: () =>
                        setState(() => _cause = _cause == cs ? null : cs),
                  ),
              ],
            ),
            const SizedBox(height: OlSpace.md),
            RontgenPicker(controller: _xray),
          ],
        ),
      ),
    ];
  }

  /// Langkah 3: jadwal.
  List<Widget> _stepSchedule(String branchId, ServiceV service) => [
    const _BookingStepHeader(title: 'Pilih Jadwal Terapi'),
    SlotPicker(
      branchId: branchId,
      serviceId: service.id,
      homeVisit: _homeVisit,
      value: _start,
      onChanged: (v) {
        setState(() => _start = v);
        // Jam dipilih → langkah jadwal selesai, lanjut otomatis ke pembayaran.
        if (v != null) {
          Future.delayed(const Duration(milliseconds: 320), () {
            if (mounted && _step == 3 && _start == v) _goTo(4);
          });
        }
      },
    ),
  ];

  /// Langkah 4: data diri yang kurang, metode bayar, ringkasan. Tombol bayar ada di bawah.
  List<Widget> _stepConfirm(
    BuildContext context,
    ({String id, String name, String address}) branch,
    ServiceV service,
  ) {
    final c = context.ol;
    final t = context.olText;
    return [
      OlSectionHeader(
        title: _homeVisit ? 'Ringkasan Pengajuan' : 'Ringkasan Booking',
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
                        '${service.durationMin} menit · ${branch.name}',
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
                  const SizedBox(height: 8),
                  _SummaryRow(
                    icon: OlIcons.pain,
                    label: 'Keluhan',
                    value: _complaint.text.trim(),
                  ),
                  if (_homeVisit && _addressText != null) ...[
                    const SizedBox(height: 8),
                    _SummaryRow(icon: OlIcons.pin, label: 'Alamat', value: _addressText!),
                  ],
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
              OlMoneyRow(label: 'Harga Member', amount: service.memberPrice!),
            ],
            if (_homeVisit)
              FutureBuilder<HomeVisitEstimateV>(
                future: _estimateFor(branch.id, service.id),
                builder: (context, snap) {
                  final e = snap.data;
                  if (e == null) {
                    return snap.hasError
                        ? OlMoneyTotal(label: 'Estimasi Biaya Layanan', amount: service.memberPrice ?? service.price)
                        : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
                  }
                  // Harga layanan mengikuti harga member bila ada (sama dengan ringkasan di atas).
                  final svc = service.memberPrice ?? service.price;
                  return HomeVisitEstimateBox(
                    estimate: HomeVisitEstimateV(
                      distanceKm: e.distanceKm,
                      transportFee: e.transportFee,
                      ratePerKm: e.ratePerKm,
                      servicePrice: svc,
                      total: svc + e.transportFee,
                      inArea: e.inArea,
                      maxKm: e.maxKm,
                    ),
                  );
                },
              )
            else ...[
              OlMoneyRow(
                label: 'Biaya layanan',
                amount: service.memberPrice ?? service.price,
              ),
              OlMoneyRow(
                label: _channel == null
                    ? 'Biaya admin'
                    : 'Biaya admin · ${_channel!.label}',
                amount: _channel?.fee ?? 0,
                muted: true,
              ),
              AnimatedOpacity(
                opacity: _feeBusy ? .35 : 1,
                duration: OlMotion.of(context, OlMotion.fast),
                child: OlMoneyTotal(
                  label: 'Total Pembayaran',
                  amount: _total(service),
                ),
              ),
            ],
          ],
        ),
      ),
      if (!_homeVisit) ...[
        const _BookingStepHeader(title: 'Metode Pembayaran'),
        PaymentChannelPicker(
          amount: service.memberPrice ?? service.price,
          value: _channel,
          onBusy: (v) => setState(() => _feeBusy = v),
          onChanged: (ch) => setState(() => _channel = ch),
        ),
      ],
      ..._dataDiri(context),
      OlTextField(
        label: 'Catatan tambahan untuk klinik (opsional)',
        controller: _note,
        hint: 'Misal: preferensi terapis atau kondisi khusus...',
        maxLines: 2,
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
                  ? 'Klinik mengonfirmasi terapis & jadwal dulu. Biaya dibayar setelah sesi selesai.'
                  : 'Pembayaran diproses otomatis & aman.',
              style: t.caption.copyWith(color: c.muted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ];
  }
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

/// "Sudah berapa lama?" — satu kotak isian: angka di kiri, satuan (Hari/Minggu/Bulan/Tahun) di kanan.
class _DurationField extends StatelessWidget {
  const _DurationField({
    required this.controller,
    required this.unit,
    required this.units,
    required this.onUnitChanged,
  });

  final TextEditingController controller;
  final String unit;
  final Map<String, String> units;
  final ValueChanged<String> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sudah berapa lama keluhan dirasakan?', style: t.fieldLabel),
        const SizedBox(height: 7),
        Container(
          height: OlSize.input,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(OlRadius.input),
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    style: t.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    cursorColor: c.brand,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Contoh: 2',
                      hintStyle: t.body.copyWith(fontSize: 16, color: c.faint),
                    ),
                  ),
                ),
              ),
              Container(width: 1.5, height: 26, color: c.line),
              PopupMenuButton<String>(
                initialValue: unit,
                onSelected: onUnitChanged,
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(OlRadius.input),
                ),
                itemBuilder: (_) => [
                  for (final e in units.entries)
                    PopupMenuItem(value: e.key, child: Text(e.value, style: t.body)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        units[unit] ?? unit,
                        style: t.bodyStrong.copyWith(color: c.brandDeep),
                      ),
                      const SizedBox(width: 4),
                      OlIcon(OlIcons.chevronDown, size: 18, color: c.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kartu pilihan tipe kunjungan (langkah 1 booking).
class _VisitTypeCard extends StatelessWidget {
  const _VisitTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.selected,
    required this.onTap,
  });

  final OlIconData icon;
  final String title, subtitle;
  final List<String> points;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final enabled = onTap != null;
    final radius = BorderRadius.circular(OlRadius.card);
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: AnimatedContainer(
        duration: OlMotion.of(context, OlMotion.fast),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          border: Border.all(color: selected ? c.brand : c.line, width: selected ? 2.2 : 1),
          boxShadow: selected ? [BoxShadow(color: c.brandSoft, spreadRadius: 3)] : OlShadow.sh1,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: Padding(
              padding: const EdgeInsets.all(OlSpace.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected ? c.brandDeep : c.brandSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: OlIcon(
                        icon,
                        size: 26,
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
                        Text(title, style: t.heading),
                        const SizedBox(height: 2),
                        Text(subtitle, style: t.caption.copyWith(color: c.muted)),
                        const SizedBox(height: OlSpace.sm),
                        for (final pt in points)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                OlIcon(OlIcons.checkCircle, size: 14, color: c.ok),
                                const SizedBox(width: 6),
                                Expanded(child: Text(pt, style: t.caption.copyWith(color: c.fg))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: OlSpace.sm),
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: selected ? c.brand : c.faint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
