import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_session.dart';

/// PS-10 Jadwal saya (`GET /v1/pasien/sessions`): mendatang & riwayat. Ubah/batal jadwal sendiri
/// menunggu aturan batas waktu dari workshop (§16 no. 8) — sementara lewat klinik.
class JadwalSayaPage extends ConsumerStatefulWidget {
  const JadwalSayaPage({super.key});

  @override
  ConsumerState<JadwalSayaPage> createState() => _JadwalSayaPageState();
}

class _JadwalSayaPageState extends ConsumerState<JadwalSayaPage> {
  bool _history = false;

  String _relative(DateTime at) {
    final days = DateUtils.dateOnly(
      at,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    return switch (days) {
      0 => 'Hari ini',
      1 => 'Besok',
      < 0 => '',
      _ => '$days hari lagi',
    };
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Jadwal saya',
    children: [
      OlSegmented<bool>(
        segments: const {false: 'Mendatang', true: 'Riwayat'},
        value: _history,
        onChanged: (v) => setState(() => _history = v),
      ),
      OlAsync<List<PasienSessionItem>>(
        key: ValueKey(_history),
        load: () => ref.read(pasienApiProvider).sessions(past: _history),
        builder: (context, list, _) {
          final c = context.ol;
          final t = context.olText;
          if (list.isEmpty) {
            return [
              OlCard(
                child: EmptyState(
                  illustration: OlIllustration.emptySchedule,
                  title: _history ? 'Belum ada riwayat' : 'Belum ada jadwal',
                  message: _history
                      ? 'Sesi yang sudah lewat muncul di sini.'
                      : 'Hubungi klinik lewat WhatsApp untuk membuat jadwal.',
                ),
              ),
            ];
          }
          return [
            for (final s in list)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        OlTag(
                          s.status.label,
                          tone: switch (s.status) {
                            SessionStatus.awaitingConfirmation =>
                              OlTagTone.warn,
                            SessionStatus.noShow ||
                            SessionStatus.cancelled => OlTagTone.crit,
                            SessionStatus.paid ||
                            SessionStatus.done => OlTagTone.ok,
                            _ => OlTagTone.outline,
                          },
                        ),
                        const Spacer(),
                        Text(
                          _relative(s.startAt),
                          style: t.body.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        text: '${Fmt.date(s.startAt)} · ',
                        children: [
                          TextSpan(
                            text: Fmt.time(s.startAt),
                            style: t.mono.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      style: t.heading.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.serviceName} · ${s.durationMin} mnt · ${s.therapistName}',
                      style: t.body.copyWith(fontSize: 14.5, color: c.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.homeVisit != null
                          ? 'Home visit · ${s.homeVisit!.address}'
                          : [
                              s.branchName,
                              if (s.branchAddress.isNotEmpty) s.branchAddress,
                            ].join(' · '),
                      style: t.body.copyWith(fontSize: 14.5),
                    ),
                  ],
                ),
              ),
            if (!_history)
              Text(
                'Untuk mengubah atau membatalkan jadwal, hubungi klinik lewat WhatsApp.',
                style: t.body.copyWith(color: c.muted),
              ),
          ];
        },
      ),
    ],
  );
}
