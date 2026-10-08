import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_helpers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  testWidgets('status bar tertutup saat digulir', (t) async {
    await openAsTherapist(t);
    await shot(t, 'SB-atas');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await pumpFor(t, const Duration(milliseconds: 500));
    await shot(t, 'SB-gulir');
    await t.tap(find.text('Riwayat').last);
    await pumpFor(t);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await pumpFor(t, const Duration(milliseconds: 500));
    await shot(t, 'SB-gulir-biasa');
  });
}
