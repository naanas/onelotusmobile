import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/app.dart';
import 'package:onelotus_staff/router/app_router.dart';

import '../test/auth/fakes.dart';

import 'app_helpers.dart';

Future<void> _go(WidgetTester t, String path) async {
  rootNavigatorKey.currentContext!.push(path);
  await pumpFor(t);
}

Future<void> _back(WidgetTester t) async {
  rootNavigatorKey.currentState!.pop();
  await pumpFor(t);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  testWidgets('aplikasi pasien', (t) async {
    phoneView(t);
    final h = AuthHarness()..device.available = false;
    await t.pumpWidget(
      shootable(
        ProviderScope(overrides: h.overrides, child: const OneLotusApp()),
      ),
    );
    // Splash → belum login → perkenalan pasien.
    await pumpFor(t, const Duration(seconds: 3));
    await shot(t, 'PS-01');

    // Layar masuk bersama: nomor HP dikenali → kode (PS-02).
    await t.tap(find.text('Lewati'));
    await pumpFor(t);
    await t.enterText(find.byType(TextField).first, '081234567890');
    await pumpFor(t, const Duration(milliseconds: 400));
    await shot(t, 'PS-02-nomor');
    await t.tap(find.text('Kirim kode lewat WhatsApp'));
    await pumpFor(t, const Duration(seconds: 1));
    await t.enterText(find.byType(TextField).first, '482');
    await pumpFor(t, const Duration(milliseconds: 300));
    await shot(t, 'PS-02');
    await t.enterText(find.byType(TextField).first, '482913');
    await pumpFor(t, const Duration(seconds: 1));

    // PS-03 → PS-04 → PS-05.
    await shot(t, 'PS-03');
    await t.tap(find.text('Hubungkan'));
    await pumpFor(t, const Duration(seconds: 1));
    await shot(t, 'PS-04');
    await t.tap(find.text('Penggunaan data kesehatan *'));
    await t.tap(find.text('Pengingat jadwal via WhatsApp *'));
    await pumpFor(t, const Duration(milliseconds: 300));
    await t.tap(find.text('Setuju & lanjutkan'));
    await pumpFor(t, const Duration(seconds: 1));
    await shot(t, 'PS-05');

    for (final (tab, name) in const [
      ('Latihan', 'PS-06'),
      ('Booking', 'PS-08-layanan'),
      ('Profil', 'PS-18'),
    ]) {
      await t.tap(find.text(tab).last);
      await pumpFor(t);
      await shot(t, name);
    }
    await t.tap(find.text('Booking').last);
    await pumpFor(t);
    await t.tap(find.text('Lanjut'));
    await pumpFor(t);
    await shot(t, 'PS-08-lokasi');
    await t.tap(find.text('Lanjut'));
    await pumpFor(t);
    await shot(t, 'PS-08');

    for (final (path, name) in const [
      ('/pasien/latihan/calf-raise', 'PS-07'),
      ('/pasien/bayar', 'PS-09'),
      ('/pasien/jadwal', 'PS-10'),
      ('/pasien/jadwal/ubah', 'PS-11'),
      ('/pasien/riwayat', 'PS-12'),
      ('/pasien/paket', 'PS-13'),
      ('/pasien/paket/beli', 'PS-14'),
      ('/pasien/struk', 'PS-15'),
      ('/pasien/poin', 'PS-16'),
      ('/pasien/notifikasi', 'PS-17'),
      ('/pasien/alamat', 'PS-19'),
      ('/pasien/hapus-akun', 'PS-20'),
    ]) {
      await _go(t, path);
      await shot(t, name);
      await _back(t);
    }
  });
}
