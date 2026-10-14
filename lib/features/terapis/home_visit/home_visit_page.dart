import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/api/one_lotus_api.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';

typedef _Visit = ({Session session, Patient? patient});

/// TR-09 Home visit: alamat & patokan (dari sesi), peringatan medis, check-in di lokasi
/// (Dijadwalkan → Berjalan, lewat outbox), rekam sesi, dan "tidak jadi" di lokasi (Tidak datang,
/// alasan wajib). Radius check-in & checklist alat menunggu aturan workshop (§16 no. 3).
class HomeVisitPage extends ConsumerStatefulWidget {
  const HomeVisitPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<HomeVisitPage> createState() => _HomeVisitPageState();
}

class _HomeVisitPageState extends ConsumerState<HomeVisitPage> {
  late Future<_Visit> _future = _load();
  bool _busy = false;

  Future<_Visit> _load() async {
    final api = ref.read(oneLotusApiProvider);
    final session = await api.session(widget.sessionId);
    Patient? patient;
    try {
      patient = await api.patient(session.patientId);
    } on AppError {
      patient = null;
    }
    return (session: session, patient: patient);
  }

  Future<void> _status(
    Session s,
    SessionStatus to, {
    String? reason,
    required String ok,
  }) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .updateStatus(s, to, reason: reason);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      context.feedback.success(ok);
      setState(() => _future = _load());
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Session s) async {
    final r = await context.feedback.choose(
      const ConfirmSpec(
        title: 'Tidak jadi di lokasi?',
        message: 'Sesi ditandai Tidak datang. Front desk melihat alasannya.',
        confirmLabel: 'Tandai tidak jadi',
        reasonLabel: 'Alasan',
      ),
    );
    if (!r.confirmed || !mounted) return;
    await _status(
      s,
      SessionStatus.noShow,
      reason: r.reason,
      ok: 'Ditandai tidak jadi.',
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_Visit>(
    future: _future,
    builder: (context, snap) {
      final v = snap.data;
      if (v != null) return _page(context, v);
      final e = snap.error;
      return OlDetailScaffold(
        title: 'Home visit',
        children: [
          if (e != null)
            OlErrorCard(
              message: e is AppError ? e.message : 'Data belum bisa dimuat.',
              refId: e is AppError ? e.refId : null,
              onRetry: () => setState(() => _future = _load()),
            )
          else
            const OlLoadingCard(),
        ],
      );
    },
  );

  Widget _page(BuildContext context, _Visit v) {
    final c = context.ol;
    final t = context.olText;
    final s = v.session;
    final hv = s.homeVisit;
    final running = s.status == SessionStatus.running;
    final waiting =
        s.status == SessionStatus.scheduled ||
        s.status == SessionStatus.arrived;
    return OlDetailScaffold(
      title: s.patientName,
      actions: [
        OlTag('Home visit · ${Fmt.time(s.startAt)}', tone: OlTagTone.warn),
      ],
      below: Text(
        '${s.serviceName} ±${s.durationMin} mnt',
        style: t.body.copyWith(fontSize: 15, color: c.muted),
      ),
      foot: [
        if (waiting)
          OlButton(
            label: 'Check-in & mulai sesi',
            icon: OlIcons.pin,
            loading: _busy,
            onPressed: _busy
                ? null
                : () => _status(
                    s,
                    SessionStatus.running,
                    ok: 'Check-in tercatat ${Fmt.time(DateTime.now())}.',
                  ),
          ),
        if (running)
          OlButton(
            label: 'Isi rekam sesi',
            onPressed: () => context.push(Routes.terapisRekam(s.id)),
          ),
        if (waiting)
          OlButton(
            label: 'Tidak jadi di lokasi',
            variant: OlButtonVariant.dangerSecondary,
            onPressed: _busy ? null : () => _cancel(s),
          ),
      ],
      children: [
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hv?.address ?? 'Alamat belum diisi',
                style: t.bodyStrong.copyWith(fontSize: 15),
              ),
              if (hv?.landmark != null)
                Text(
                  'Patokan: ${hv!.landmark}',
                  style: t.body.copyWith(color: c.muted),
                ),
              if (hv?.distanceKm != null)
                Text(
                  '${hv!.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km dari cabang',
                  style: t.body.copyWith(color: c.muted),
                ),
            ],
          ),
        ),
        if (v.patient?.medicalAlert != null)
          OlBanner(tone: OlBannerTone.crit, message: v.patient!.medicalAlert!),
        OlCard(
          child: Column(
            children: [
              OlInfoRow(label: 'Status', value: s.status.label),
              if (s.startedAt != null)
                OlInfoRow(label: 'Check-in', value: Fmt.time(s.startedAt!)),
              if (s.note != null) OlInfoRow(label: 'Catatan', value: s.note!),
            ],
          ),
        ),
      ],
    );
  }
}
