import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/ui/body_map/body_map_data.dart';

import 'app_helpers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  testWidgets('TR-04 rekam sesi', (t) async {
    await openAsTherapist(t);
    await t.runAsync(BodyMapData.load);
    await go(t, '/terapis/rekam/s2');
    await pumpFor(t, const Duration(seconds: 1));
    await shot(t, 'TR-04a');
    await t.drag(find.byType(ListView).last, const Offset(0, -380));
    await pumpFor(t, const Duration(milliseconds: 600));
    await shot(t, 'TR-04map');
    await t.drag(find.byType(ListView).last, const Offset(0, 380));
    await pumpFor(t, const Duration(milliseconds: 300));
    for (final part in ['b', 'c', 'd']) {
      await t.drag(find.byType(ListView).last, const Offset(0, -700));
      await pumpFor(t, const Duration(milliseconds: 500));
      await shot(t, 'TR-04$part');
    }
  });

  testWidgets('modul terapis', (t) async {
    await openAsTherapist(t);
    await shot(t, 'TR-01');
    await t.tap(find.text('Pasien').last);
    await pumpFor(t);
    await shot(t, 'TR-06');
    await t.tap(find.text('Riwayat').last);
    await pumpFor(t);
    await shot(t, 'TR-07');
    for (final (path, name) in const [
      ('/terapis/jadwal-minggu', 'TR-02'),
      ('/terapis/cuti', 'TR-03'),
      ('/terapis/pasien/p0387', 'TR-05'),
      ('/terapis/sesi/s1', 'TR-08'),
      ('/terapis/home-visit/s4', 'TR-09'),
      ('/terapis/home-visit/s4/tagih', 'TR-10'),
      ('/terapis/kas', 'TR-11'),
      ('/terapis/komisi', 'TR-12'),
      ('/terapis/pasien/p0387/latihan', 'TR-13'),
      ('/terapis/pilih-pasien', 'TR-14'),
    ]) {
      await go(t, path);
      await shot(t, name);
      await back(t);
    }
  });
}
