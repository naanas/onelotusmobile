import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-06 Buat jadwal: pasien → layanan → lokasi & terapis → waktu (slot dari server) → ringkasan.
/// [walkIn] = sesi tanpa jadwal (KS-01): tanpa langkah waktu, langsung berstatus Hadir.
/// Bentrok dicegah di SlotPicker (`GET /v1/slots`) dan diperiksa ulang server saat simpan.
class BuatJadwalPage extends ConsumerStatefulWidget {
  const BuatJadwalPage({super.key, this.walkIn = false, this.patientId});

  final bool walkIn;

  /// Pasien sudah dipilih (dibuka dari detail pasien).
  final String? patientId;

  @override
  ConsumerState<BuatJadwalPage> createState() => _BuatJadwalPageState();
}

class _BuatJadwalPageState extends ConsumerState<BuatJadwalPage> {
  late final List<String> _titles = [
    'Pilih pasien',
    'Pilih layanan',
    'Lokasi & terapis',
    if (!widget.walkIn) 'Pilih waktu',
    'Ringkasan',
  ];
  int _step = 0;
  bool _busy = false;

  // Pilihan
  Patient? _patient;
  Service? _service;
  String? _room; // null = tanpa ruang
  bool _homeVisit = false;
  final _address = TextEditingController();
  final _note = TextEditingController();
  Therapist? _therapist; // null = siapa saja
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  Slot? _slot;

  // Data dari server
  List<Patient> _patients = const [];
  String _query = '';
  Timer? _debounce;
  List<Service>? _services;
  List<Room>? _rooms;
  List<Therapist>? _therapists;
  BranchDetail? _branchDetail;
  List<Slot>? _slots;
  AppError? _error;

  OneLotusApi get _api => ref.read(oneLotusApiProvider);
  Branch get _branch => ref.read(authProvider).activeBranch!;

  int get _timeStep => widget.walkIn ? -1 : 3;
  int get _lastStep => _titles.length - 1;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    if (widget.patientId != null) {
      _api.patient(widget.patientId!).then((p) {
        if (mounted) setState(() => _patient = p);
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() f) async {
    setState(() => _error = null);
    try {
      await f();
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadPatients() => _guard(() async {
    final r = await _api.patients(query: _query);
    if (mounted) setState(() => _patients = r.items);
  });

  Future<void> _loadStep(int step) async {
    switch (step) {
      case 1 when _services == null:
        await _guard(() async {
          final s = await _api.services(_branch.id);
          if (mounted) setState(() => _services = s);
        });
      case 2 when _rooms == null || _therapists == null:
        await _guard(() async {
          final rooms = await _api.rooms(_branch.id);
          final ts = await _api.therapists(_branch.id, date: _day);
          final b = await _api.branch(_branch.id);
          if (mounted) {
            setState(() {
              _rooms = rooms;
              _therapists = ts;
              _branchDetail = b;
            });
          }
        });
      case 3 when !widget.walkIn:
        await _loadSlots();
    }
  }

  Future<void> _loadSlots() => _guard(() async {
    setState(() {
      _slots = null;
      _slot = null;
    });
    final s = await _api.slots(
      branchId: _branch.id,
      date: _day,
      serviceId: _service!.id,
      therapistId: _therapist?.id,
      room: _homeVisit ? null : _room,
    );
    if (mounted) setState(() => _slots = s);
  });

  bool get _canNext => switch (_step) {
    0 => _patient != null,
    1 => _service != null,
    2 => !_homeVisit || _address.text.trim().isNotEmpty,
    _ when _step == _timeStep => _slot != null,
    _ => true,
  };

  Future<void> _next() async {
    if (_step < _lastStep) {
      setState(() => _step++);
      await _loadStep(_step);
      return;
    }
    setState(() => _busy = true);
    try {
      final s = await _api.createSession(
        patientId: _patient!.id,
        serviceId: _service!.id,
        branchId: _branch.id,
        therapistId: _therapist?.id,
        startAt: widget.walkIn ? null : _slot!.startAt,
        room: _homeVisit ? null : _room,
        homeVisit: _homeVisit ? HomeVisit(address: _address.text.trim()) : null,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        walkIn: widget.walkIn,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      context.feedback.success(
        widget.walkIn
            ? '${s.patientName} masuk antrian (Hadir) dengan ${s.therapistName}.'
            : 'Jadwal tersimpan: ${Fmt.dayShort(s.startAt)} ${Fmt.time(s.startAt)} dengan ${s.therapistName}.',
      );
      Navigator.of(context).maybePop();
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final msg = e.fieldErrors.values.expand((v) => v).firstOrNull;
      if (msg != null) {
        context.feedback.info(msg);
        if (!widget.walkIn && e.fieldErrors.containsKey('start_at')) {
          setState(() => _step = _timeStep);
          await _loadSlots();
        }
      } else {
        context.feedback.error(e, retry: _next);
      }
    }
  }

  Widget _radio<T>(
    List<(T, String, String?)> options,
    T? value,
    ValueChanged<T> onPick,
  ) => OlRadioList<T>(
    options: [
      for (final (v, title, sub) in options)
        OlRadioOption(value: v, title: title, subtitle: sub),
    ],
    value: value,
    onChanged: (v) => setState(() => onPick(v)),
  );

  List<Widget> _patientStep() => [
    OlSearchField(
      hint: 'Cari nama, #nomor, atau 4 digit HP',
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 350), () {
          _query = v.trim();
          _loadPatients();
        });
      },
    ),
    if (_patients.isEmpty)
      Text('Tidak ada pasien yang cocok.', style: context.olText.body)
    else
      _radio<String>(
        [for (final p in _patients) (p.id, p.name, Fmt.patientNo(p.number))],
        _patient?.id,
        (id) => _patient = _patients.firstWhere((p) => p.id == id),
      ),
  ];

  List<Widget> _locationStep() {
    final rooms = _rooms;
    final ts = _therapists;
    if (rooms == null || ts == null) return const [OlLoadingCard()];
    return [
      const OlOverline('Lokasi'),
      _radio<String>(
        [
          if (rooms.isEmpty) ('', 'Di klinik', null),
          for (final r in rooms) (r.name, _branch.name, r.name),
          if (!widget.walkIn) ('__home', 'Home visit', 'Alamat wajib diisi'),
        ],
        _homeVisit ? '__home' : (_room ?? ''),
        (v) {
          _homeVisit = v == '__home';
          _room = _homeVisit || v.isEmpty ? null : v;
        },
      ),
      if (_homeVisit) ...[
        OlTextField(
          label: 'Alamat home visit',
          isRequired: true,
          controller: _address,
          onChanged: (_) => setState(() {}),
        ),
      ],
      const OlOverline('Terapis'),
      _radio<String>(
        [
          ('', 'Siapa saja', 'Dipilih terapis yang kosong'),
          for (final t in ts)
            (t.id, t.name, t.available == false ? 'Cuti hari ini' : null),
        ],
        _therapist?.id ?? '',
        (id) =>
            _therapist = id.isEmpty ? null : ts.firstWhere((t) => t.id == id),
      ),
      OlTextField(label: 'Catatan (opsional)', controller: _note),
    ];
  }

  List<Widget> _timeStepWidgets() {
    final c = context.ol;
    final t = context.olText;
    final today = DateUtils.dateOnly(DateTime.now());
    final hours = _branchDetail?.openingHours ?? const {};
    final days = [for (var i = 0; i < 7; i++) today.add(Duration(days: i))];
    final slots = _slots;
    return [
      OlDayStrip(
        month: DateFormat('MMM', 'id_ID').format(_day),
        days: [
          for (final d in days)
            OlDay(
              DateFormat('EEE', 'id_ID').format(d),
              d.day,
              closed: hours.isNotEmpty && !hours.containsKey('${d.weekday}'),
            ),
        ],
        selected: _day.day,
        onSelect: (n) {
          setState(() => _day = days.firstWhere((d) => d.day == n));
          _loadSlots();
        },
      ),
      if (slots == null)
        const OlLoadingCard()
      else if (slots.isEmpty)
        Text(
          'Cabang tutup di hari ini.',
          style: t.body.copyWith(color: c.muted),
        )
      else
        OlSlotPicker(
          slots: [
            for (final s in slots)
              OlSlot(
                Fmt.time(s.startAt),
                unavailableLabel: s.available
                    ? null
                    : (s.unavailableReason ?? 'Penuh'),
              ),
          ],
          selected: _slot == null ? null : Fmt.time(_slot!.startAt),
          onSelect: (v) => setState(
            () => _slot = slots.firstWhere((s) => Fmt.time(s.startAt) == v),
          ),
        ),
      Text(
        'Slot dihitung server dari jam buka, durasi layanan, serta ketersediaan terapis & ruang — jadwal bentrok tidak bisa dipilih.',
        style: t.body.copyWith(color: c.muted),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final summary = OlCard(
      child: Column(
        children: [
          if (_patient != null)
            OlInfoRow(
              label: 'Pasien',
              value: '${_patient!.name} · ${Fmt.patientNo(_patient!.number)}',
            ),
          if (_step >= 1 && _service != null)
            OlInfoRow(
              label: 'Layanan',
              value: '${_service!.name} · ${_service!.durationMin} mnt',
            ),
          if (_step >= 2) ...[
            OlInfoRow(
              label: 'Lokasi',
              value: _homeVisit
                  ? 'Home visit · ${_address.text.trim()}'
                  : [_branch.name, ?_room].join(' · '),
            ),
            OlInfoRow(
              label: 'Terapis',
              value: _therapist?.name ?? 'Siapa saja',
            ),
          ],
          if (_step == _lastStep)
            OlInfoRow(
              label: 'Waktu',
              value: widget.walkIn
                  ? 'Sekarang (walk-in)'
                  : '${Fmt.dayShort(_slot!.startAt)} · ${Fmt.time(_slot!.startAt)}',
            ),
        ],
      ),
    );

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: OlDetailScaffold(
        title: widget.walkIn ? 'Sesi tanpa jadwal' : 'Buat jadwal',
        close: true,
        context_:
            'Langkah ${_step + 1} dari ${_titles.length} · ${_titles[_step]}',
        below: OlStepProgress(count: _titles.length, current: _step),
        foot: [
          OlButton(
            label: _step == _lastStep
                ? (widget.walkIn ? 'Masukkan ke antrian' : 'Simpan jadwal')
                : 'Lanjut',
            loading: _busy,
            onPressed: _canNext && !_busy ? _next : null,
          ),
        ],
        children: [
          if (_step > 0) summary,
          if (_error != null)
            OlErrorCard(
              message: _error!.message,
              refId: _error!.refId,
              onRetry: () => _step == 0 ? _loadPatients() : _loadStep(_step),
            ),
          ...switch (_step) {
            0 => _patientStep(),
            1 =>
              _services == null
                  ? const [OlLoadingCard()]
                  : [
                      _radio<String>(
                        [
                          for (final s in _services!)
                            (
                              s.id,
                              s.name,
                              '${s.durationMin} mnt · ${Fmt.money(s.price)}',
                            ),
                        ],
                        _service?.id,
                        (id) =>
                            _service = _services!.firstWhere((s) => s.id == id),
                      ),
                    ],
            2 => _locationStep(),
            _ when _step == _timeStep => _timeStepWidgets(),
            _ => [
              const OlBanner(
                icon: OlIcons.checkCircle,
                message: 'Server memeriksa ulang bentrok jadwal saat disimpan.',
              ),
            ],
          },
        ],
      ),
    );
  }
}
