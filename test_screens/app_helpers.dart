import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onelotus_staff/app.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/models/models.dart';
import 'package:onelotus_staff/router/app_router.dart';

import '../test/auth/fakes.dart';
import 'shot.dart';

export 'shot.dart';

Future<void> pumpFor(
  WidgetTester t, [
  Duration d = const Duration(milliseconds: 800),
]) async {
  for (var i = 0; i < d.inMilliseconds ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Buka aplikasi sebagai Dimas (terapis), langsung di beranda.
Future<void> openAsTherapist(WidgetTester t) async {
  phoneView(t);
  final h = AuthHarness()..device.available = false;
  h.clock.now = DateTime(2026, 10, 6, 10, 42);
  final c = h.container();
  await t.runAsync(() async {
    final a = c.read(authProvider.notifier);
    await a.login('dimas.terapis', 'terapis123', remember: false);
    await a.setPin('123456');
    await a.completeFirstLogin();
    await a.chooseContext(
      Role.terapis,
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

Future<void> go(WidgetTester t, String path) async {
  rootNavigatorKey.currentContext!.push(path);
  await pumpFor(t);
}

Future<void> back(WidgetTester t) async {
  rootNavigatorKey.currentState!.pop();
  await pumpFor(t);
}
