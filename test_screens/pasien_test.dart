import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/pasien/pasien_app.dart';

import 'app_helpers.dart';

Future<void> _go(WidgetTester t, String path) async {
  pasienNavigatorKey.currentContext!.push(path);
  await pumpFor(t);
}

Future<void> _back(WidgetTester t) async {
  pasienNavigatorKey.currentState!.pop();
  await pumpFor(t);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  testWidgets('aplikasi pasien', (t) async {
    phoneView(t);
    await t.pumpWidget(shootable(const ProviderScope(child: PasienApp())));
    await pumpFor(t, const Duration(seconds: 1));
    await shot(t, 'PS-01');

    // PS-02: nomor HP → kode.
    await t.tap(find.text('Lewati'));
    await pumpFor(t);
    await t.enterText(find.byType(TextField).first, '081234567890');
    await pumpFor(t, const Duration(milliseconds: 300));
    await shot(t, 'PS-02-nomor');
    await t.tap(find.text('Kirim kode lewat WhatsApp'));
    await pumpFor(t);
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
      ('/latihan/calf-raise', 'PS-07'),
      ('/bayar', 'PS-09'),
      ('/jadwal', 'PS-10'),
      ('/jadwal/ubah', 'PS-11'),
      ('/riwayat', 'PS-12'),
      ('/paket', 'PS-13'),
      ('/paket/beli', 'PS-14'),
      ('/struk', 'PS-15'),
      ('/poin', 'PS-16'),
      ('/notifikasi', 'PS-17'),
      ('/alamat', 'PS-19'),
      ('/hapus-akun', 'PS-20'),
    ]) {
      await _go(t, path);
      await shot(t, name);
      await _back(t);
    }
  });
}
