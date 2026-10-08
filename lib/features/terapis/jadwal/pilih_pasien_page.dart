import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/auth/auth_controller.dart';
import '../../../data/models/models.dart';
import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';
import 'jadwal_controller.dart';

/// TR-14 Pilih pasien (FAB, saat tidak ada sesi berjalan): sesi berstatus Hadir → Mulai → TR-04.
/// Terapis tidak membuat sesi sendiri (jadwal & tagihan satu pintu di front desk).
class PilihPasienPage extends ConsumerWidget {
  const PilihPasienPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ol;
    final t = context.olText;
    final today = dateOnly(ref.watch(clockProvider)());
    final schedule = ref.watch(therapistScheduleProvider(today)).value;
    final arrived = [
      for (final s in schedule?.sessions ?? const <Session>[])
        if (s.status == SessionStatus.arrived ||
            s.status == SessionStatus.running)
          s,
    ];

    Future<void> pick(Session s) async {
      if (s.status == SessionStatus.arrived) {
        final blocked = startBlockReason(schedule!, s);
        if (blocked != null) {
          context.feedback.info(blocked);
          return;
        }
        await ref.read(therapistScheduleProvider(today).notifier).start(s);
      }
      if (context.mounted) context.pushReplacement(Routes.terapisRekam(s.id));
    }

    return OlDetailScaffold(
      title: 'Mulai sesi',
      close: true,
      below: Text(
        'Pilih pasien yang sudah ditandai hadir oleh front desk.',
        style: t.body.copyWith(fontSize: 15, color: c.muted),
      ),
      children: [
        OlOverline('Hadir sekarang · ${arrived.length}'),
        if (arrived.isEmpty)
          const OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptySchedule,
              title: 'Belum ada pasien hadir',
              message:
                  'Pasien muncul di sini setelah front desk menandainya hadir.',
            ),
          )
        else
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, s) in arrived.indexed)
                  OlListItem(
                    leading: OlAvatar(name: s.patientName),
                    title: s.patientName,
                    subtitle:
                        '${Fmt.time(s.startAt)} · ${s.isNewPatient ? 'pasien baru' : s.serviceName}'
                        '${s.room != null ? ' · ${s.room}' : ''}',
                    trailing: OlTag.session(s.status),
                    divider: i < arrived.length - 1,
                    onTap: () => pick(s),
                  ),
              ],
            ),
          ),
        OlSearchField(hint: 'Cari pasien lain', onChanged: (_) {}),
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pasien belum ada sesi hari ini?', style: t.heading),
              const SizedBox(height: 6),
              Text(
                'Sesi dibuat oleh front desk agar jadwal dan tagihan tetap satu pintu.',
                style: t.body.copyWith(color: c.muted),
              ),
              const SizedBox(height: 12),
              OlButton.secondary(
                label: 'Minta kasir buat sesi',
                small: true,
                expand: false,
                onPressed: () => context.feedback.success(
                  'Permintaan terkirim ke front desk.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
