import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../shared/slot_sheet.dart';

/// Rencana pindah satu sesi.
class _Move {
  _Move(this.session);
  final Session session;
  Therapist? therapist;
  Slot? slot;
  String? error;
  bool get ready => therapist != null || slot != null;
}

/// KS-08 Pindah sesi massal (terapis cuti / berhalangan, §6.3): pilih terapis yang sesinya
/// dipindah, lalu per sesi pilih terapis pengganti atau jam baru. Disimpan lewat
/// `POST /v1/sessions/bulk-move`; sesi tanpa pengganti ditandai "Perlu tindakan".
class PindahMassalPage extends ConsumerStatefulWidget {
  const PindahMassalPage({super.key, this.therapistId, this.from, this.to});

  final String? therapistId;
  final DateTime? from;
  final DateTime? to;

  @override
  ConsumerState<PindahMassalPage> createState() => _PindahMassalPageState();
}

class _PindahMassalPageState extends ConsumerState<PindahMassalPage> {
  List<Therapist>? _therapists;
  late String? _therapistId = widget.therapistId;
  List<_Move>? _moves;
  AppError? _error;
  bool _busy = false;

  OneLotusApi get _api => ref.read(oneLotusApiProvider);
  Branch get _branch => ref.read(authProvider).activeBranch!;

  DateTime get _from => widget.from ?? DateUtils.dateOnly(DateTime.now());
  DateTime get _to => widget.to ?? _from.add(const Duration(days: 14));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final ts = await _api.therapists(_branch.id);
      List<_Move>? moves;
      if (_therapistId != null) {
        final list = await _api.sessions(
          branchId: _branch.id,
          from: _from,
          to: _to,
          therapistId: _therapistId,
        );
        moves = [
          for (final s in list)
            if (s.status == SessionStatus.scheduled ||
                s.status == SessionStatus.awaitingConfirmation)
              _Move(s),
        ];
      }
      if (mounted) {
        setState(() {
          _therapists = ts;
          _moves = moves;
        });
      }
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pickTherapist(_Move m) async {
    final options = [
      for (final t in _therapists ?? const <Therapist>[])
        if (t.id != m.session.therapistId) t,
    ];
    final pick = await context.feedback.sheet<String>(
      title: 'Terapis pengganti',
      message:
          '${m.session.patientName} · ${Fmt.dayShort(m.session.startAt)} ${Fmt.time(m.session.startAt)}',
      actions: [
        for (final t in options)
          SheetAction(t.name, t.id, variant: OlButtonVariant.secondary),
      ],
    );
    if (pick != null) {
      setState(() {
        m.therapist = options.firstWhere((t) => t.id == pick);
        m.slot = null;
        m.error = null;
      });
    }
  }

  Future<void> _pickTime(_Move m) async {
    final slot = await pickSlot(
      context,
      title: 'Jam baru · ${m.session.patientName}',
      branchId: m.session.branchId,
      serviceId: m.session.serviceId,
      excludeSessionId: m.session.id,
    );
    if (slot != null) {
      setState(() {
        m.slot = slot;
        m.therapist = null;
        m.error = null;
      });
    }
  }

  Future<void> _save() async {
    final moves = _moves!;
    setState(() => _busy = true);
    try {
      final results = await _api.bulkMove([
        for (final m in moves)
          (
            sessionId: m.session.id,
            therapistId: m.therapist?.id,
            startAt: m.slot?.startAt,
          ),
      ], reason: 'Pindah massal');
      if (!mounted) return;
      final moved = results.where((r) => r.status == 'moved').length;
      final failed = results.where((r) => r.status == 'failed').toList();
      final pending = results.where((r) => r.status == 'needs_action').length;
      if (failed.isEmpty) {
        context.feedback.success(
          '$moved sesi dipindah${pending > 0 ? ', $pending ditandai perlu tindakan' : ''}.',
        );
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        _busy = false;
        for (final r in failed) {
          final m = moves.firstWhere((m) => m.session.id == r.sessionId);
          m.error = r.firstError ?? 'Gagal dipindah.';
        }
        moves.removeWhere(
          (m) => results.any(
            (r) => r.sessionId == m.session.id && r.status != 'failed',
          ),
        );
      });
      context.feedback.info(
        '$moved sesi dipindah. ${failed.length} gagal — periksa yang ditandai.',
      );
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.feedback.error(e, retry: _save);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final moves = _moves;
    final ts = _therapists;
    final ready = moves?.where((m) => m.ready).length ?? 0;
    final name = ts?.where((x) => x.id == _therapistId).firstOrNull?.name;

    return OlDetailScaffold(
      onRefresh: _load,
      title: moves == null
          ? 'Pindah sesi massal'
          : 'Pindahkan ${moves.length} sesi',
      context_: name == null
          ? null
          : '$name · ${Fmt.dateNoDay(_from)} – ${Fmt.dateNoDay(_to)}',
      foot: [
        if (moves != null && moves.isNotEmpty)
          OlButton(
            label: ready == moves.length
                ? 'Simpan $ready perpindahan'
                : 'Simpan ($ready dipindah, ${moves.length - ready} perlu tindakan)',
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
        else if (ts == null)
          const OlLoadingCard()
        else if (_therapistId == null) ...[
          Text('Sesi terapis mana yang dipindah?', style: t.heading),
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, x) in ts.indexed)
                  OlListItem(
                    leading: OlAvatar(name: x.name),
                    title: x.name,
                    showChevron: true,
                    divider: i < ts.length - 1,
                    onTap: () {
                      setState(() => _therapistId = x.id);
                      _load();
                    },
                  ),
              ],
            ),
          ),
        ] else if (moves == null)
          const OlLoadingCard()
        else if (moves.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptySchedule,
              title: 'Tidak ada sesi untuk dipindah',
              message: 'Terapis ini tidak punya sesi terjadwal di rentang ini.',
            ),
          )
        else
          for (final m in moves)
            OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${Fmt.dayShort(m.session.startAt)} · ${Fmt.time(m.session.startAt)}',
                          style: t.mono.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      m.ready
                          ? const OlTag('Siap', tone: OlTagTone.ok)
                          : const OlTag('Perlu tindakan', tone: OlTagTone.crit),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(m.session.patientName, style: t.heading),
                  Text(
                    [
                      m.session.serviceName,
                      if (m.session.isHomeVisit) 'home visit',
                    ].join(' · '),
                    style: t.body.copyWith(color: c.muted),
                  ),
                  if (m.therapist != null || m.slot != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      m.therapist != null
                          ? '→ ${m.therapist!.name}, jam sama'
                          : '→ ${Fmt.dayShort(m.slot!.startAt)} ${Fmt.time(m.slot!.startAt)}, terapis sama',
                      style: t.bodyStrong,
                    ),
                  ],
                  if (m.error != null) ...[
                    const SizedBox(height: 6),
                    Text(m.error!, style: t.body.copyWith(color: c.crit)),
                  ],
                  const SizedBox(height: 10),
                  OlFootRow(
                    children: [
                      OlButton.secondary(
                        label: 'Ganti terapis',
                        small: true,
                        onPressed: () => _pickTherapist(m),
                      ),
                      OlButton.secondary(
                        label: 'Ganti jam',
                        small: true,
                        onPressed: () => _pickTime(m),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        if (moves != null && moves.isNotEmpty)
          const OlBanner(
            message:
                'Sesi tanpa pengganti tetap ditandai "Perlu tindakan" di antrian. Pemberitahuan WhatsApp ke pasien menyusul saat layanan WhatsApp tersedia.',
          ),
      ],
    );
  }
}
