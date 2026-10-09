import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/app.dart';
import 'package:onelotus_staff/router/routes.dart';

import '../test/auth/fakes.dart';

import 'app_helpers.dart';

/// WB-01 formulir pasien baru (di aplikasi) — dibuka dari layar masuk / QR KS-02.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  testWidgets('formulir intake', (t) async {
    phoneView(t);
    final h = AuthHarness()..device.available = false;
    await t.pumpWidget(
      shootable(
        ProviderScope(overrides: h.overrides, child: const OneLotusApp()),
      ),
    );
    await pumpFor(t, const Duration(seconds: 3));
    await t.tap(find.text('Lewati'));
    await pumpFor(t);
    await shot(t, 'UM-04-intake-link');
    expect(find.text('Pasien baru di klinik? Isi formulir'), findsOneWidget);

    await go(t, Routes.intakeForm('demo'));
    await shot(t, 'WB-01');

    await t.enterText(find.byType(TextField).first, 'Sari Wulandari');
    await t.tap(find.text('Kirim formulir'));
    await pumpFor(t);
    await shot(t, 'WB-01-error');
  });
}
