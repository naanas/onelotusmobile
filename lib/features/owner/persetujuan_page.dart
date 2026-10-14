import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

typedef _Data = ({
  List<LeaveRequest> leaves,
  List<PasswordResetRequest> resets,
});

/// OW-06 Persetujuan: cuti terapis (TR-03) dan reset password (UM-06) dari server.
/// Tolak wajib alasan. Setuju cuti → sesi terdampak bisa langsung dipindah (KS-08);
/// setuju reset → password sementara ditampilkan sekali. Refund & diskon menunggu modul pembayaran.
class PersetujuanPage extends ConsumerStatefulWidget {
  const PersetujuanPage({super.key});

  @override
  ConsumerState<PersetujuanPage> createState() => _PersetujuanPageState();
}

class _PersetujuanPageState extends ConsumerState<PersetujuanPage> {
  int _gen = 0;

  OneLotusApi get _api => ref.read(oneLotusApiProvider);

  Future<_Data> _load() async {
    final r = await (
      _api.leaves(status: 'pending'),
      _api.passwordResets(),
    ).wait;
    return (leaves: r.$1, resets: r.$2);
  }

  void _reload() => setState(() => _gen++);

  void _fail(AppError e) {
    final msg = e.fieldErrors.values.expand((v) => v).firstOrNull;
    msg != null ? context.feedback.info(msg) : context.feedback.error(e);
  }

  Future<void> _decideLeave(LeaveRequest l, bool approve) async {
    String? reason;
    if (!approve) {
      final r = await context.feedback.choose(
        ConfirmSpec(
          title: 'Tolak cuti ${l.therapistName}?',
          message: 'Terapis diberi tahu beserta alasannya.',
          confirmLabel: 'Tolak',
          reasonLabel: 'Alasan',
        ),
      );
      if (!r.confirmed) return;
      reason = r.reason;
    }
    try {
      final affected = await _api.decideLeave(
        l.id,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _reload();
      if (!approve) {
        context.feedback.success('Cuti ditolak.');
      } else if (affected.isEmpty) {
        context.feedback.success('Cuti disetujui. Tidak ada sesi terdampak.');
      } else {
        context.feedback.success(
          'Cuti disetujui. ${affected.length} sesi perlu dipindah.',
          action: FeedbackAction(
            'Pindahkan',
            () => context.push(
              Uri(
                path: Routes.kasirPindahMassal,
                queryParameters: {
                  'terapis': l.therapistId,
                  'dari': formatDayParam(l.startsAt),
                  'sampai': formatDayParam(
                    l.endsAt.add(const Duration(days: 1)),
                  ),
                },
              ).toString(),
            ),
          ),
        );
      }
    } on AppError catch (e) {
      if (mounted) _fail(e);
    }
  }

  Future<void> _decideReset(PasswordResetRequest r, bool approve) async {
    if (!approve) {
      final ok = await context.feedback.confirm(
        ConfirmSpec(
          title: 'Tolak permintaan ${r.username}?',
          message: 'Password tidak berubah.',
          confirmLabel: 'Tolak',
        ),
      );
      if (!ok) return;
    }
    try {
      final pw = await _api.decidePasswordReset(r.id, approve: approve);
      if (!mounted) return;
      _reload();
      if (pw == null) {
        context.feedback.success('Permintaan ditolak.');
        return;
      }
      await showTemporaryPassword(
        context,
        name: r.name ?? r.username,
        password: pw,
      );
    } on AppError catch (e) {
      if (mounted) _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Persetujuan',
    children: [
      OlAsync<_Data>(
        key: ValueKey(_gen),
        load: _load,
        builder: (context, d, _) {
          final c = context.ol;
          final t = context.olText;
          if (d.leaves.isEmpty && d.resets.isEmpty) {
            return const [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptyInbox,
                  title: 'Tidak ada yang menunggu',
                  message: 'Pengajuan cuti dan reset password muncul di sini.',
                ),
              ),
            ];
          }
          Widget card({
            required String kind,
            required String by,
            required String title,
            String? detail,
            required VoidCallback onReject,
            required VoidCallback onApprove,
          }) => OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    OlTag(kind, tone: OlTagTone.muted),
                    const Spacer(),
                    Text(by, style: t.body.copyWith(color: c.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title, style: t.heading.copyWith(fontSize: 17)),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(detail, style: t.body.copyWith(color: c.muted)),
                ],
                const SizedBox(height: 12),
                OlFootRow(
                  children: [
                    OlButton.secondary(
                      label: 'Tolak',
                      small: true,
                      onPressed: onReject,
                    ),
                    OlButton(
                      label: 'Setujui',
                      small: true,
                      onPressed: onApprove,
                    ),
                  ],
                ),
              ],
            ),
          );
          return [
            for (final l in d.leaves)
              card(
                kind: 'Cuti',
                by: '${l.therapistName} · ${Fmt.dateNoDay(l.createdAt)}',
                title: l.allDay
                    ? '${Fmt.dateNoDay(l.startsAt)}${l.endsAt.difference(l.startsAt).inDays > 1 ? ' – ${Fmt.dateNoDay(l.endsAt.subtract(const Duration(days: 1)))}' : ''} · ${l.reason}'
                    : '${Fmt.dateNoDay(l.startsAt)} ${Fmt.time(l.startsAt)}–${Fmt.time(l.endsAt)} · ${l.reason}',
                detail: [
                  if (l.note != null) '"${l.note}"',
                  '${l.affectedSessions} sesi terdampak',
                ].join(' · '),
                onReject: () => _decideLeave(l, false),
                onApprove: () => _decideLeave(l, true),
              ),
            for (final r in d.resets)
              card(
                kind: 'Reset password',
                by: '${r.username} · ${Fmt.dateNoDay(r.createdAt)}',
                title: r.name ?? 'Username tidak terdaftar',
                detail: r.note == null ? null : '"${r.note}"',
                onReject: () => _decideReset(r, false),
                onApprove: () => _decideReset(r, true),
              ),
          ];
        },
      ),
    ],
  );
}

String formatDayParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Password sementara (OW-06, OW-08): ditampilkan sekali, bisa disalin.
Future<void> showTemporaryPassword(
  BuildContext context, {
  required String name,
  required String password,
}) => context.feedback.sheet<void>(
  title: 'Password sementara untuk $name',
  message:
      'Berikan langsung ke yang bersangkutan. Password ini hanya ditampilkan sekali dan wajib diganti saat masuk.',
  child: Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          password,
          textAlign: TextAlign.center,
          style: context.olText.mono.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: OlSpace.md),
        OlButton.secondary(
          label: 'Salin',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: password));
            context.feedback.info('Password disalin.');
          },
        ),
      ],
    ),
  ),
  actions: const [SheetAction('Selesai', null)],
);
