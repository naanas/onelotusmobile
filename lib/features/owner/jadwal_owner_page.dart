import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

typedef _Day = ({List<Therapist> therapists, List<Session> sessions});

/// OW-02 Jadwal semua terapis (tab Jadwal owner): sesi cabang per hari dikelompokkan per terapis
/// (`GET /v1/sessions` + `GET /v1/branches/{id}/therapists`), penanda cuti, tambah sesi, pindah massal.
class JadwalOwnerPage extends ConsumerStatefulWidget {
  const JadwalOwnerPage({super.key});

  @override
  ConsumerState<JadwalOwnerPage> createState() => _JadwalOwnerPageState();
}

class _JadwalOwnerPageState extends ConsumerState<JadwalOwnerPage> {
  final _days = [
    for (var i = -1; i < 6; i++)
      DateUtils.dateOnly(DateTime.now()).add(Duration(days: i)),
  ];
  late DateTime _day = _days[1];
  int _gen = 0;

  Future<_Day> _load() async {
    final api = ref.read(oneLotusApiProvider);
    final branch = ref.read(authProvider).activeBranch!;
    final r = await (
      api.therapists(branch.id, date: _day),
      api.sessions(
        branchId: branch.id,
        from: _day,
        to: _day.add(const Duration(days: 1)),
      ),
    ).wait;
    return (therapists: r.$1, sessions: r.$2);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlPageBody(
      header: OlAppHeader(
        title: 'Jadwal',
        actions: [
          OlButton(
            label: '+ Sesi',
            small: true,
            expand: false,
            onPressed: () async {
              await context.push(Routes.kasirBuatJadwal);
              setState(() => _gen++);
            },
          ),
        ],
      ),
      children: [
        OlDayStrip(
          month: DateFormat('MMM', 'id_ID').format(_day),
          days: [
            for (final d in _days)
              OlDay(DateFormat('EEE', 'id_ID').format(d), d.day),
          ],
          selected: _day.day,
          onSelect: (n) => setState(() {
            _day = _days.firstWhere((d) => d.day == n);
            _gen++;
          }),
        ),
        OlAsync<_Day>(
          key: ValueKey('$_day-$_gen'),
          load: _load,
          builder: (context, d, reload) {
            if (d.therapists.isEmpty) {
              return const [
                OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptySchedule,
                    title: 'Belum ada terapis di cabang ini',
                    message: 'Tambahkan staf berperan terapis di Kelola staf.',
                  ),
                ),
              ];
            }
            return [
              for (final th in d.therapists)
                Builder(
                  builder: (context) {
                    final mine = [
                      for (final s in d.sessions)
                        if (s.therapistId == th.id &&
                            s.status != SessionStatus.cancelled)
                          s,
                    ];
                    return OlCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              OlAvatar(name: th.name),
                              const SizedBox(width: OlSpace.md),
                              Expanded(child: Text(th.name, style: t.heading)),
                              if (th.available == false)
                                const OlTag('Cuti', tone: OlTagTone.warn)
                              else
                                Text(
                                  '${mine.length} sesi',
                                  style: t.body.copyWith(color: c.muted),
                                ),
                            ],
                          ),
                          for (final s in mine) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                SizedBox(
                                  width: 52,
                                  child: Text(
                                    Fmt.time(s.startAt),
                                    style: t.mono.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    [
                                      s.patientName,
                                      if (s.isHomeVisit)
                                        'home visit'
                                      else
                                        ?s.room,
                                    ].join(' · '),
                                    style: t.body,
                                  ),
                                ),
                                OlTag(
                                  s.status.label,
                                  tone: switch (s.status) {
                                    SessionStatus.running => OlTagTone.fill,
                                    SessionStatus.paid => OlTagTone.ok,
                                    SessionStatus.noShow => OlTagTone.crit,
                                    SessionStatus.awaitingConfirmation =>
                                      OlTagTone.warn,
                                    _ => OlTagTone.muted,
                                  },
                                ),
                              ],
                            ),
                          ],
                          if (mine.any(
                            (s) => s.status == SessionStatus.scheduled,
                          )) ...[
                            const SizedBox(height: 10),
                            OlButton.secondary(
                              label: 'Pindahkan sesi ${th.name}',
                              small: true,
                              onPressed: () async {
                                await context.push(
                                  Uri(
                                    path: Routes.kasirPindahMassal,
                                    queryParameters: {
                                      'terapis': th.id,
                                      'dari': formatDay(_day),
                                      'sampai': formatDay(
                                        _day.add(const Duration(days: 1)),
                                      ),
                                    },
                                  ).toString(),
                                );
                                reload();
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ];
          },
        ),
      ],
    );
  }
}

String formatDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
