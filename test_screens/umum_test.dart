import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_helpers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  testWidgets('modul umum', (t) async {
    await openAsTherapist(t);
    await t.tap(find.text('Akun').last);
    await pumpFor(t);
    await shot(t, 'UM-11');
    for (final (path, name) in const [
      ('/perbarui', 'UM-02'),
      ('/pemeliharaan', 'UM-03'),
      ('/notifikasi', 'UM-09'),
      ('/cari', 'UM-10'),
      ('/ubah-password', 'UM-12'),
      ('/pengaturan-notifikasi', 'UM-13'),
      ('/status-sinkron', 'UM-14'),
      ('/bantuan', 'UM-15'),
    ]) {
      await go(t, path);
      if (name == 'UM-10') {
        await t.enterText(find.byType(TextField).first, 'rina');
        await pumpFor(t);
      }
      await shot(t, name);
      await back(t);
    }
  });
}
