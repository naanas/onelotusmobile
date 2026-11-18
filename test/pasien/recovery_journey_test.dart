import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/data/pasien/pasien_app_api.dart';
import 'package:onelotus_staff/pasien/beranda/recovery_journey.dart';
import 'package:onelotus_staff/ui/body_map/body_map_selection.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  final now = DateTime(2026, 11, 16);

  test('belum ada aktivitas → semua 0, tahapan belum dimulai', () {
    final j = RecoveryJourney.from(sessions: const [], programs: const [], now: now);
    expect([j.pain, j.painDropPct, j.programPct, j.adherencePct], [0, 0, 0, 0]);
    expect(j.highlights, isEmpty);
    expect(j.stages.every((s) => s.state == StageState.pending), isTrue);
  });

  test('area sesi terakhir dipetakan ke mode', () {
    final j = RecoveryJourney.from(
      sessions: const [],
      programs: const [],
      areas: const {'knees:right': 'treated', 'calves:right': 'calming'},
      now: now,
    );
    expect(j.areas, {'knees:right': BodyMode.treated, 'calves:right': BodyMode.calming});
  });

  test('nyeri turun & program berjalan minggu ke-4 dari 8', () {
    final j = RecoveryJourney.from(
      sessions: [
        PatientSessionV(sessionId: '2', date: DateTime(2026, 11, 1), painBefore: 5, painAfter: 2),
        PatientSessionV(sessionId: '1', date: DateTime(2026, 10, 20), painBefore: 8, painAfter: 6),
      ],
      programs: [
        ProgramV(id: 'p', items: const [], startsOn: DateTime(2026, 10, 24), endsOn: DateTime(2026, 12, 19), adherence: 85),
      ],
      now: now,
    );
    expect(j.pain, 2);
    expect(j.painDropPct, 75);
    expect(j.adherencePct, 85);
    expect(j.programPct, 41);
    expect(j.stages[2].state, StageState.active);
    expect(j.stages[2].subtitle, 'Berjalan · minggu 4 dari 8');
    expect(j.stages[3].state, StageState.pending);
    expect(j.highlights.map((h) => h.text), ['Nyeri berkurang 75%', 'Latihan 85%']);
    expect(j.areas, isEmpty);
  });
}
