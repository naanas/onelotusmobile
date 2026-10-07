import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/app.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/models/staff_user.dart';

import 'fakes.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> enterPin(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.bySemanticsLabel(d).last);
    await t.pump();
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('kasir: login → atur PIN → notifikasi → tab Antrian', (t) async {
    final h = AuthHarness();
    h.device.available = false;
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const OneLotusApp()),
    );
    await settle(t);
    expect(find.text('Masuk ke One Lotus'), findsOneWidget);

    // Validasi kosong.
    await t.tap(find.text('Masuk'));
    await t.pump();
    expect(find.text('Username wajib diisi.'), findsOneWidget);

    await t.enterText(find.byType(TextFormField).at(0), 'sinta.kasir');
    await t.enterText(find.byType(TextFormField).at(1), 'salah');
    await t.tap(find.text('Masuk'));
    await settle(t);
    expect(find.text('Username atau password tidak cocok.'), findsOneWidget);

    await t.enterText(find.byType(TextFormField).at(1), 'kasir123');
    await t.tap(find.text('Masuk'));
    await settle(t);

    // UM-05 langkah PIN (password tidak sementara → mulai dari PIN).
    expect(find.text('Atur PIN 6 digit'), findsOneWidget);
    expect(find.text('Langkah 1 dari 2 · Login pertama'), findsOneWidget);
    await enterPin(t, '123456');
    expect(find.text('Ulangi PIN'), findsOneWidget);
    await enterPin(t, '123456');
    expect(find.text('PIN cocok'), findsOneWidget);
    await t.tap(find.text('Lanjut'));
    await settle(t);

    expect(find.text('Izinkan notifikasi'), findsWidgets);
    await t.tap(find.text('Nanti saja'));
    await settle(t);

    // Tab bar kasir.
    for (final label in ['Antrian', 'Pasien', 'Kasir', 'Akun']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Ringkasan'), findsNothing);
    expect(
      find.bySemanticsLabel('Pasien baru atau tampilkan QR intake'),
      findsOneWidget,
    );

    // Akun → Keluar (dialog konfirmasi) → kembali ke login.
    await t.tap(find.text('Akun'));
    await settle(t);
    expect(find.text('Sinta Maharani'), findsOneWidget);
    await t.tap(find.text('Keluar'));
    await settle(t);
    await t.tap(find.text('Keluar').last);
    await settle(t);
    expect(find.text('Masuk ke One Lotus'), findsOneWidget);
  });

  testWidgets('owner: tab bar 5 tanpa FAB', (t) async {
    final h = AuthHarness();
    h.device.available = false;
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);

    final c = h.container();
    addTearDown(c.dispose);
    // Siapkan akun owner yang sudah setup lalu pilih peran owner.
    final auth = c.read(authProvider.notifier);
    // Future nyata (bukan fake-async testWidgets).
    await t.runAsync(() async {
      await auth.login('rudi.owner', 'owner123');
      await auth.setPin('123456');
      await auth.completeFirstLogin();
      await auth.chooseContext(
        Role.owner,
        c.read(authProvider).user!.branches.first,
      );
    });

    // Buka ulang aplikasi dengan penyimpanan yang sama.
    await t.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const OneLotusApp()),
    );
    await settle(t);
    // Splash membaca sesi → terkunci (UM-01 → UM-07).
    expect(find.text('Halo, Rudi'), findsOneWidget);
    await enterPin(t, '123456');
    await settle(t);
    for (final label in ['Ringkasan', 'Jadwal', 'Pasien', 'Laporan', 'Akun']) {
      expect(find.text(label), findsWidgets);
    }
    expect(
      find.bySemanticsLabel(RegExp('QR intake|pilih pasien')),
      findsNothing,
    );
  });
}
