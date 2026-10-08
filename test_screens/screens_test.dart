import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/app.dart';
import 'package:onelotus_staff/ui/ol_toggle.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';

import '../test/auth/fakes.dart';
import 'shot.dart';

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final steps = d.inMilliseconds ~/ 50;
  for (var i = 0; i < steps; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> pin(WidgetTester t, String p) async {
  for (final d in p.split('')) {
    await t.tap(find.bySemanticsLabel(d).last);
    await t.pump();
  }
}

Future<void> login(WidgetTester t, String u, String p) async {
  // Satu aplikasi: lewati perkenalan pasien → layar masuk bersama.
  final skip = find.text('Lewati');
  if (skip.evaluate().isNotEmpty) {
    await t.tap(skip);
    await pumpFor(t, const Duration(seconds: 1));
  }
  await t.enterText(find.byType(TextFormField).at(0), u);
  await pumpFor(t, const Duration(milliseconds: 400));
  await t.enterText(find.byType(TextFormField).at(1), p);
  await t.tap(find.text('Masuk'));
  await pumpFor(t, const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  testWidgets('alur kasir', (t) async {
    phoneView(t);
    final h = AuthHarness()..device.available = false;
    // Latensi nyata agar splash terlihat.
    await t.pumpWidget(
      shootable(
        ProviderScope(overrides: h.overrides, child: const OneLotusApp()),
      ),
    );
    await pumpFor(t, const Duration(milliseconds: 300));
    await shot(t, '01_splash_a');
    await pumpFor(t, const Duration(milliseconds: 500));
    await shot(t, '01_splash_b');
    await pumpFor(t, const Duration(milliseconds: 500));
    await shot(t, '01_splash_c');
    await pumpFor(t, const Duration(milliseconds: 250));
    await shot(t, '01_splash_to_login');
    await pumpFor(t, const Duration(seconds: 2));
    await shot(t, '02_onboarding_pasien');
    await t.tap(find.text('Lewati'));
    await pumpFor(t, const Duration(seconds: 1));
    await shot(t, '02_login');
    await login(t, 'sinta.kasir', 'kasir123');
    await shot(t, '03_pin');
    await pin(t, '123456');
    await pin(t, '123456');
    await t.tap(find.text('Lanjut'));
    await pumpFor(t, const Duration(seconds: 1));
    await shot(t, '04_notif');
    await t.tap(find.text('Nanti saja'));
    await pumpFor(t, const Duration(seconds: 1));
    await shot(t, '05_kasir_antrian');
    await t.tap(find.text('Pasien'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 90));
    await shot(t, '06a_tab_transisi');
    await pumpFor(t, const Duration(milliseconds: 600));
    await shot(t, '06_kasir_pasien');
    await t.tap(find.text('Akun'));
    await pumpFor(t, const Duration(milliseconds: 600));
    await shot(t, '07_kasir_akun');
    await t.tap(find.byType(OlToggle).first);
    await pumpFor(t, const Duration(milliseconds: 600));
    await shot(t, '07b_akun_offline');
  });

  testWidgets('alur terapis multi peran', (t) async {
    phoneView(t);
    final h = AuthHarness()..device.available = false;
    h.clock.now = DateTime(2026, 10, 6, 10, 42);
    await t.pumpWidget(
      shootable(
        ProviderScope(overrides: h.overrides, child: const OneLotusApp()),
      ),
    );
    await pumpFor(t, const Duration(seconds: 2));
    await login(t, 'dimas.terapis', 'terapis123');
    await pin(t, '123456');
    await pin(t, '123456');
    await t.tap(find.text('Lanjut'));
    await pumpFor(t, const Duration(seconds: 1));
    await t.tap(find.text('Nanti saja'));
    await pumpFor(t, const Duration(seconds: 1));
    await shot(t, '08_pilih_peran');
    await t.tap(find.text('Masuk sebagai Terapis'));
    await pumpFor(t, const Duration(seconds: 1));
    await pumpFor(t, const Duration(seconds: 1));
    await shot(t, '09_terapis_jadwal');
    await t.drag(find.byType(ListView).first, const Offset(0, -500));
    await pumpFor(t, const Duration(milliseconds: 500));
    await shot(t, '09b_terapis_jadwal_bawah');
    await t.drag(find.byType(ListView).first, const Offset(0, 800));
    await pumpFor(t, const Duration(milliseconds: 500));
    await t.tap(find.text('home visit'));
    await pumpFor(t, const Duration(milliseconds: 500));
    await shot(t, '09c_filter_home_visit');
    await t.tap(find.text('home visit'));
    await pumpFor(t, const Duration(milliseconds: 300));
    await t.tap(find.text('Riwayat'));
    await pumpFor(t, const Duration(milliseconds: 600));
    await shot(t, '10_terapis_riwayat');
  });

  testWidgets('kunci', (t) async {
    phoneView(t);
    final h = AuthHarness()..device.available = false;
    final c = h.container();
    await t.runAsync(() async {
      final a = c.read(authProvider.notifier);
      await a.login('baru.terapis', 'sementara1');
    });
    await t.pumpWidget(
      shootable(
        UncontrolledProviderScope(container: c, child: const OneLotusApp()),
      ),
    );
    await pumpFor(t, const Duration(seconds: 2));
    await shot(t, '11_first_login_pw');
  });
}
