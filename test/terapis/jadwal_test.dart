import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/data/providers.dart';
import 'package:onelotus_staff/features/terapis/jadwal/jadwal_controller.dart';
import 'package:onelotus_staff/features/terapis/jadwal/jadwal_page.dart';
import 'package:onelotus_staff/theme/app_theme.dart';
import 'package:onelotus_staff/ui/feedback/app_feedback.dart';

import '../auth/fakes.dart';

/// Login sebagai Dimas (terapis, Klinik Pusat) tanpa melewati layar.
Future<ProviderContainer> loggedInDimas(AuthHarness h) async {
  final c = h.container();
  final auth = c.read(authProvider.notifier);
  await auth.login('dimas.terapis', 'terapis123');
  await auth.setPin('123456');
  await auth.completeFirstLogin();
  await auth.chooseContext(
    Role.terapis,
    c.read(authProvider).user!.branches.first,
  );
  return c;
}

final pushed = <String>[];

Future<void> pumpJadwal(WidgetTester t, ProviderContainer c) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final nav = GlobalKey<NavigatorState>();
  final messenger = GlobalKey<ScaffoldMessengerState>();
  pushed.clear();
  final router = GoRouter(
    navigatorKey: nav,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: JadwalPage()),
      ),
      GoRoute(
        path: '/:rest(.*)',
        builder: (_, s) {
          pushed.add(s.matchedLocation);
          return const Scaffold(body: Text('tujuan'));
        },
      ),
    ],
  );
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: FeedbackScope(
        feedback: AppFeedback(messengerKey: messenger, navigatorKey: nav),
        child: MaterialApp.router(
          theme: buildOlTheme(),
          scaffoldMessengerKey: messenger,
          routerConfig: router,
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('aturan', () {
    final base = Session(
      id: 'x',
      patientId: 'p',
      patientName: 'P',
      patientNumber: 1,
      therapistId: 'u1',
      therapistName: 'D',
      serviceId: 's',
      serviceName: 'S',
      branchId: 'b',
      startAt: DateTime(2026, 10, 6, 15),
      durationMin: 60,
      status: SessionStatus.scheduled,
    );

    test('terlambat > 15 mnt hanya bila belum hadir', () {
      expect(base.isLateAt(DateTime(2026, 10, 6, 15, 15)), isFalse);
      expect(base.isLateAt(DateTime(2026, 10, 6, 15, 16)), isTrue);
      expect(
        base
            .copyWith(status: SessionStatus.arrived)
            .isLateAt(DateTime(2026, 10, 6, 16)),
        isFalse,
      );
    });

    test('Mulai sesi: hanya status Hadir & hanya 1 sesi berjalan', () {
      final arrived = base.copyWith(status: SessionStatus.arrived);
      final running = base.copyWith(status: SessionStatus.running);
      final day = DaySchedule(day: DateTime(2026, 10, 6), sessions: [arrived]);
      expect(startBlockReason(day, arrived), isNull);
      expect(startBlockReason(day, base), isNotNull);
      final busy = DaySchedule(
        day: DateTime(2026, 10, 6),
        sessions: [
          Session.fromJson({...running.toJson(), 'id': 'y'}),
          arrived,
        ],
      );
      expect(
        startBlockReason(busy, arrived),
        contains('Hanya 1 sesi berjalan'),
      );
    });
  });

  testWidgets('TR-01: ringkasan, kartu, berikutnya, sesi berjalan', (t) async {
    final h = AuthHarness()..clock.now = DateTime(2026, 10, 6, 10, 42);
    late ProviderContainer c;
    await t.runAsync(() async => c = await loggedInDimas(h));
    addTearDown(c.dispose);
    await pumpJadwal(t, c);

    expect(find.text('Pagi, Dimas'), findsOneWidget);
    expect(find.text('sesi hari ini'), findsOneWidget);
    for (final n in [
      'Rina Setiawati',
      'Andi Pratama',
      'Budi Hartono',
      'Sari Wulandari',
    ]) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.textContaining('berikutnya dalam 2 jam'), findsOneWidget);
    expect(find.textContaining('Berjalan · 12:'), findsOneWidget);
    expect(c.read(runningSessionProvider)!.patientName, 'Andi Pratama');

    await t.tap(find.text('Buka rekam sesi'));
    await t.pumpAndSettle();
    expect(pushed, ['/terapis/rekam/s2']);
  });

  testWidgets(
    'Tidak datang: alasan wajib, lalu status berubah & masuk outbox',
    (t) async {
      final h = AuthHarness()..clock.now = DateTime(2026, 10, 6, 13, 20);
      late ProviderContainer c;
      await t.runAsync(() async => c = await loggedInDimas(h));
      addTearDown(c.dispose);
      await pumpJadwal(t, c);

      // Budi (13.00, belum hadir) terlambat 20 mnt → banner.
      expect(find.textContaining('Terlambat 20 mnt'), findsOneWidget);

      await t.tap(find.byTooltip('Aksi lain untuk Budi Hartono'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tandai tidak datang'));
      await t.pumpAndSettle();
      expect(find.text('Tandai Budi Hartono tidak datang?'), findsOneWidget);
      await t.enterText(find.byType(TextFormField), 'Tidak bisa dihubungi');
      await t.pump();
      await t.tap(find.text('Tandai tidak datang').last);
      await t.pumpAndSettle();

      expect(find.text('Tidak datang'), findsOneWidget);
      await t.runAsync(() => c.read(syncEngineProvider).flush());
      expect(h.backend.sessions['s4']!.status, SessionStatus.noShow);
    },
  );

  testWidgets(
    'offline dengan cache: banner + data terakhir; tanpa cache: layar error',
    (t) async {
      final h = AuthHarness()..clock.now = DateTime(2026, 10, 6, 10, 42);
      late ProviderContainer c;
      await t.runAsync(() async => c = await loggedInDimas(h));
      addTearDown(c.dispose);
      await pumpJadwal(t, c); // mengisi cache hari ini

      h.backend.offline = true;
      await t.runAsync(
        () => c
            .read(therapistScheduleProvider(DateTime(2026, 10, 6)).notifier)
            .refresh(),
      );
      await t.pump();
      expect(
        find.text('Kamu sedang offline. Data tersimpan di HP.'),
        findsOneWidget,
      );
      expect(find.textContaining('Data terakhir diperbarui'), findsOneWidget);
      expect(find.text('Andi Pratama'), findsOneWidget);

      // Hari lain belum pernah dimuat → layar error offline.
      await t.tap(find.bySemanticsLabel('Kam 8'));
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Kamu sedang offline'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      h.backend.offline = false;
      await t.tap(find.text('Coba lagi'));
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Fajar Nugroho'), findsOneWidget);
      expect(find.text('Menunggu konfirmasi'), findsOneWidget);
    },
  );
}
