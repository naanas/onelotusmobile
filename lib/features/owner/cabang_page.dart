import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

const _dayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

/// OW-17 Cabang & ruang (`/v1/branches/{id}`): nama, alamat, nomor WA, jam operasional per hari
/// (dipakai perhitungan slot), dan daftar ruang. Radius check-in & tarif transport menunggu
/// layanan home visit.
class CabangPage extends ConsumerStatefulWidget {
  const CabangPage({super.key});

  @override
  ConsumerState<CabangPage> createState() => _CabangPageState();
}

class _CabangPageState extends ConsumerState<CabangPage> {
  late String _branchId = ref.read(authProvider).activeBranch!.id;
  BranchDetail? _detail;
  AppError? _error;
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _wa = TextEditingController();
  Map<String, List<String>> _hours = {};
  Map<String, List<String>> _errors = const {};
  bool _busy = false;

  OneLotusApi get _api => ref.read(oneLotusApiProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _wa.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _detail = null;
    });
    try {
      final d = await _api.branch(_branchId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _name.text = d.branch.name;
        _address.text = d.branch.address;
        _wa.text = d.waNumber ?? '';
        _hours = {
          for (final e in d.openingHours.entries) e.key: [...e.value],
        };
      });
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _switchBranch() async {
    final branches = ref.read(authProvider).user?.branches ?? const <Branch>[];
    final b = await context.feedback.sheet<String>(
      title: 'Pilih cabang',
      actions: [
        for (final b in branches)
          SheetAction(
            b.name,
            b.id,
            variant: b.id == _branchId
                ? OlButtonVariant.primary
                : OlButtonVariant.secondary,
          ),
      ],
    );
    if (b != null && b != _branchId) {
      _branchId = b;
      await _load();
    }
  }

  Future<String?> _time(String initial) async {
    final parts = initial.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
    );
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editDay(int iso) async {
    final key = '$iso';
    final cur = _hours[key];
    final open = await _time(cur?.first ?? '08:00');
    if (open == null || !mounted) return;
    final close = await _time(cur?.last ?? '20:00');
    if (close == null) return;
    setState(() => _hours[key] = [open, close]);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _errors = const {};
    });
    try {
      final d = await _api.updateBranch(
        _branchId,
        name: _name.text.trim(),
        address: _address.text.trim(),
        openingHours: _hours,
        waNumber: _wa.text.trim().isEmpty ? null : _wa.text.trim(),
      );
      if (!mounted) return;
      setState(() => _detail = d);
      context.feedback.success('Cabang disimpan.');
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.fieldErrors);
      if (e.fieldErrors.isEmpty) context.feedback.error(e, retry: _save);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _room({Room? room}) async {
    final name = await context.feedback.formSheet<String>(
      title: room == null ? 'Ruang baru' : 'Ubah ${room.name}',
      builder: (ctx, close) {
        var v = room?.name ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OlTextField(
              label: 'Nama ruang',
              initialValue: v,
              onChanged: (s) => v = s,
            ),
            const SizedBox(height: OlSpace.lg),
            OlButton(
              label: room == null ? 'Tambah ruang' : 'Simpan',
              onPressed: () {
                if (v.trim().isNotEmpty) close(v.trim());
              },
            ),
          ],
        );
      },
    );
    if (name == null || !mounted) return;
    try {
      await _api.saveRoom(
        _branchId,
        roomId: room?.id,
        name: name,
        capacity: room?.capacity ?? 1,
      );
      await _load();
    } on AppError catch (e) {
      if (!mounted) return;
      final msg = e.fieldErrors.values.expand((v) => v).firstOrNull;
      msg != null ? context.feedback.info(msg) : context.feedback.error(e);
    }
  }

  Future<void> _deactivateRoom(Room room) async {
    final ok = await context.feedback.confirm(
      ConfirmSpec(
        title: 'Nonaktifkan ${room.name}?',
        message: 'Ruang tidak bisa dipilih lagi untuk jadwal baru.',
        confirmLabel: 'Nonaktifkan',
      ),
    );
    if (!ok) return;
    try {
      await _api.saveRoom(
        _branchId,
        roomId: room.id,
        name: room.name,
        capacity: room.capacity,
        isActive: false,
      );
      await _load();
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final d = _detail;
    final many =
        (ref.watch(authProvider.select((a) => a.user?.branches.length)) ?? 0) >
        1;
    String? err(String f) => _errors[f]?.firstOrNull;
    return OlDetailScaffold(
      title: d?.branch.name ?? 'Cabang & ruang',
      titleTrailing: many
          ? OlButton.text(label: 'Ganti', onPressed: _switchBranch)
          : null,
      foot: [
        if (d != null)
          OlButton(
            label: 'Simpan cabang',
            loading: _busy,
            onPressed: _busy ? null : _save,
          ),
      ],
      children: [
        if (_error != null)
          OlErrorCard(
            message: _error!.message,
            refId: _error!.refId,
            onRetry: _load,
          )
        else if (d == null)
          const OlLoadingCard()
        else ...[
          OlTextField(
            label: 'Nama cabang',
            isRequired: true,
            controller: _name,
            error: err('name'),
          ),
          OlTextField(
            label: 'Alamat',
            isRequired: true,
            controller: _address,
            error: err('address'),
          ),
          OlTextField(
            label: 'Nomor WhatsApp cabang',
            controller: _wa,
            keyboardType: TextInputType.phone,
            error: err('wa_number'),
          ),
          const OlOverline('Jam operasional'),
          if (err('opening_hours') != null)
            Text(
              err('opening_hours')!,
              style: t.caption.copyWith(color: c.crit),
            ),
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (var iso = 1; iso <= 7; iso++)
                  OlListItem(
                    title: _dayNames[iso - 1],
                    subtitle: _hours['$iso'] == null
                        ? 'Tutup'
                        : '${_hours['$iso']!.first.replaceAll(':', '.')}–${_hours['$iso']!.last.replaceAll(':', '.')}',
                    trailing: OlToggle(
                      semanticLabel: 'Buka hari ${_dayNames[iso - 1]}',
                      value: _hours['$iso'] != null,
                      onChanged: (v) => setState(() {
                        if (v) {
                          _hours['$iso'] = ['08:00', '20:00'];
                        } else {
                          _hours.remove('$iso');
                        }
                      }),
                    ),
                    divider: iso < 7,
                    onTap: _hours['$iso'] == null ? null : () => _editDay(iso),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              const Expanded(child: OlOverline('Ruang')),
              OlButton.text(label: '+ Tambah ruang', onPressed: () => _room()),
            ],
          ),
          if (d.rooms.isEmpty)
            Text(
              'Belum ada ruang. Selama kosong, jadwal bisa dibuat tanpa memilih ruang.',
              style: t.body.copyWith(color: c.muted),
            )
          else
            OlCard(
              padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
              child: Column(
                children: [
                  for (final (i, r) in d.rooms.indexed)
                    OlListItem(
                      title: r.name,
                      subtitle: 'Kapasitas ${r.capacity}',
                      trailing: OlIconButton(
                        icon: OlIcons.close,
                        semanticLabel: 'Nonaktifkan ${r.name}',
                        onPressed: () => _deactivateRoom(r),
                      ),
                      divider: i < d.rooms.length - 1,
                      onTap: () => _room(room: r),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
