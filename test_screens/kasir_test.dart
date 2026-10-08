import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/app.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';

import '../test/auth/fakes.dart';
import 'app_helpers.dart';

Future<void> openAsCashier(WidgetTester t) async {
  phoneView(t);
  final h = AuthHarness()..device.available = false;
  h.clock.now = DateTime(2026, 10, 6, 10, 42);
  final c = h.container();
  await t.runAsync(() async {
    final a = c.read(authProvider.notifier);
    await a.login('sinta.kasir', 'kasir123', remember: false);
    await a.setPin('123456');
    await a.completeFirstLogin();
  });
  addTearDown(c.dispose);
  await t.pumpWidget(
    shootable(
      UncontrolledProviderScope(container: c, child: const OneLotusApp()),
    ),
  );
  await pumpFor(t, const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  testWidgets('modul kasir', (t) async {
    await openAsCashier(t);
    await shot(t, 'KS-01');
    await t.tap(find.text('Pasien').last);
    await pumpFor(t);
    await shot(t, 'KS-03');
    await t.tap(find.text('Kasir').last);
    await pumpFor(t);
    await shot(t, 'KS-09');
    await t.tap(find.text('Akun').last);
    await pumpFor(t);
    await shot(t, 'KS-akun');
    for (final (path, name) in const [
      ('/kasir/intake', 'KS-02'),
      ('/kasir/pasien-form', 'KS-04'),
      ('/kasir/pasien/p0412', 'KS-05'),
      ('/kasir/buat-jadwal', 'KS-06'),
      ('/kasir/booking', 'KS-07'),
      ('/kasir/pindah-massal', 'KS-08'),
      ('/kasir/bayar', 'KS-10'),
      ('/kasir/struk', 'KS-11'),
      ('/kasir/jual-paket', 'KS-12'),
      ('/kasir/riwayat', 'KS-13'),
      ('/kasir/refund', 'KS-14'),
      ('/kasir/verifikasi-transfer', 'KS-15'),
      ('/kasir/terima-kas', 'KS-16'),
      ('/kasir/tutup-kas', 'KS-17'),
      ('/kasir/piutang', 'KS-18'),
    ]) {
      await go(t, path);
      await shot(t, name);
      if (name == 'KS-06') {
        for (var i = 0; i < 3; i++) {
          await t.tap(find.text('Lanjut'));
          await pumpFor(t, const Duration(milliseconds: 400));
        }
        await shot(t, 'KS-06-waktu');
      }
      if (name == 'KS-10') {
        await t.tap(find.text('QRIS').first);
        await pumpFor(t, const Duration(milliseconds: 400));
        await shot(t, 'KS-10-qris');
        await t.tap(find.text('Paket').first);
        await pumpFor(t, const Duration(milliseconds: 400));
        await shot(t, 'KS-10-gabungan');
      }
      await back(t);
    }
  });
}
