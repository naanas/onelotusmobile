// Konteks navigator global dipakai berulang di antara pump — aman di test.
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/app.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/data/providers.dart';
import 'package:onelotus_staff/features/terapis/jadwal/jadwal_controller.dart';
import 'package:onelotus_staff/features/umum/sync_details.dart';
import 'package:onelotus_staff/router/app_router.dart';
import 'package:onelotus_staff/ui/ui.dart';

import '../test/auth/fakes.dart';
import 'app_helpers.dart';

Future<ProviderContainer> _open(WidgetTester t) async {
  phoneView(t);
  final h = AuthHarness()..device.available = false;
  h.clock.now = DateTime(2026, 10, 6, 10, 42);
  final c = h.container();
  await t.runAsync(() async {
    final a = c.read(authProvider.notifier);
    await a.login('dimas.terapis', 'terapis123', remember: false);
    await a.setPin('123456');
    await a.completeFirstLogin();
    await a.chooseContext(
      Role.terapis,
      c.read(authProvider).user!.branches.first,
    );
  });
  addTearDown(c.dispose);
  await t.pumpWidget(
    shootable(
      UncontrolledProviderScope(container: c, child: const OneLotusApp()),
    ),
  );
  await pumpFor(t, const Duration(seconds: 2));
  return c;
}

BuildContext get _ctx => rootNavigatorKey.currentContext!;

Future<void> _dismiss(WidgetTester t) async {
  rootNavigatorKey.currentState!.pop();
  await pumpFor(t, const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  testWidgets('layar state', (t) async {
    final c = await _open(t);

    // ST-01: Minggu, klinik tutup.
    c.read(selectedDayProvider.notifier).select(DateTime(2026, 10, 11));
    await pumpFor(t);
    await shot(t, 'ST-01');

    // ST-02: memuat (tangkap frame pertama setelah pindah hari).
    await t.tap(find.text('7').first);
    await t.pump();
    await shot(t, 'ST-02');
    await pumpFor(t);

    // ST-03: gangguan server.
    c.read(mockServerDownProvider.notifier).set(true);
    await t.tap(find.text('8').first);
    await pumpFor(t);
    await shot(t, 'ST-03');
    c.read(mockServerDownProvider.notifier).set(false);

    // ST-04: offline, data dari cache.
    await t.tap(find.text('6').first);
    await pumpFor(t);
    c.read(mockOfflineProvider.notifier).set(true);
    await t.tap(find.text('7').first);
    await pumpFor(t);
    await t.tap(find.text('6').first);
    await pumpFor(t);
    _ctx.feedback.success('Tersimpan di HP. Akan terkirim saat ada sinyal.');
    await pumpFor(t, const Duration(milliseconds: 400));
    await shot(t, 'ST-04');
    c.read(mockOfflineProvider.notifier).set(false);
    await pumpFor(t, const Duration(seconds: 4));

    // ST-07..09: sheet.
    openSyncDetails(_ctx, const SyncFailed(3));
    await pumpFor(t);
    await shot(t, 'ST-07');
    await _dismiss(t);

    showDuplicatePatientSheet(
      _ctx,
      existing: const PatientBrief(
        name: 'Rina Setiawati',
        number: '#0387',
        detail: '12 Mei 1999 · HP berakhiran 4417 · 6 sesi',
      ),
      incoming: const PatientBrief(
        name: 'Rina Setiawati',
        detail: 'Rina Setiawati · 12 Mei 1999 · HP berakhiran 9920',
      ),
    );
    await pumpFor(t);
    await shot(t, 'ST-08');
    await _dismiss(t);

    showConflictSheet(
      _ctx,
      mine: const ConflictVersion(
        label: 'Versi HP ini · 09.51',
        text: 'Lanjut calf raise 3×12, kontrol Kamis.',
      ),
      theirs: const ConflictVersion(
        label: 'Versi tablet ruang 2 · 09.53',
        text: 'Lanjut calf raise 3×12 + kompres hangat, kontrol Kamis.',
      ),
    );
    await pumpFor(t);
    await shot(t, 'ST-09');
    await _dismiss(t);

    // ST-14 dari alur nyata: Akun → Keluar saat ada catatan belum terkirim.
    await go(t, '/status-sinkron');
    await shot(t, 'ST-umum14');
    await t.tap(find.text('Pilih versi'));
    await pumpFor(t);
    await shot(t, 'ST-09-alur');
    await _dismiss(t);
    await back(t);
  });
}
