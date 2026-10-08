import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/app.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/models/staff_user.dart';

import '../test/auth/fakes.dart';
import 'app_helpers.dart';

Future<void> openAsOwner(WidgetTester t) async {
  phoneView(t);
  final h = AuthHarness()..device.available = false;
  h.clock.now = DateTime(2026, 10, 6, 20, 5);
  final c = h.container();
  await t.runAsync(() async {
    final a = c.read(authProvider.notifier);
    await a.login('rudi.owner', 'owner123', remember: false);
    await a.setPin('123456');
    await a.completeFirstLogin();
    await a.chooseContext(
      Role.owner,
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
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  testWidgets('modul owner', (t) async {
    await openAsOwner(t);
    await shot(t, 'OW-01');
    for (final (tab, name) in const [
      ('Jadwal', 'OW-02'),
      ('Pasien', 'OW-03'),
      ('Laporan', 'OW-04'),
      ('Akun', 'OW-akun'),
    ]) {
      await t.tap(find.text(tab).last);
      await pumpFor(t);
      await shot(t, name);
    }
    for (final (path, name) in const [
      ('/owner/ekspor', 'OW-05'),
      ('/owner/persetujuan', 'OW-06'),
      ('/owner/komisi', 'OW-07'),
      ('/owner/staf', 'OW-08'),
      ('/owner/layanan', 'OW-09'),
      ('/owner/paket', 'OW-10'),
      ('/owner/aturan-komisi', 'OW-11'),
      ('/owner/voucher', 'OW-12'),
      ('/owner/poin', 'OW-13'),
      ('/owner/template', 'OW-14'),
      ('/owner/pustaka', 'OW-15'),
      ('/owner/pengumuman', 'OW-16'),
      ('/owner/cabang', 'OW-17'),
      ('/owner/audit', 'OW-18'),
      ('/owner/rekonsiliasi', 'OW-19'),
      ('/owner/pengingat', 'OW-20'),
      ('/kasir/piutang', 'OW-piutang'),
    ]) {
      await go(t, path);
      await shot(t, name);
      await back(t);
    }
  });
}
