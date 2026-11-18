import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/theme/app_theme.dart';
import 'package:onelotus_staff/ui/ui.dart';

void main() {
  setUp(() => OlAsync.minRefreshGap = Duration.zero);
  tearDown(() => OlAsync.minRefreshGap = const Duration(seconds: 2));

  testWidgets('layar terlihat lagi / app dibuka lagi → data dimuat ulang diam-diam', (tester) async {
    var calls = 0;
    var fail = false;
    Completer<String>? pending;
    Future<String> load() {
      calls++;
      if (fail) return Future.error(StateError('jaringan'));
      pending = Completer<String>();
      return pending!.future;
    }

    final visible = ValueNotifier(true);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOlTheme(),
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, v, _) => TickerMode(
              enabled: v,
              child: OlAsync<String>(load: load, builder: (_, d, _) => [Text(d)]),
            ),
          ),
        ),
      ),
    );
    pending!.complete('v1');
    await tester.pump();
    expect(find.text('v1'), findsOneWidget);
    expect(calls, 1);

    // Pindah tab (TickerMode mati) lalu kembali → muat ulang; data lama tetap tampil.
    await tester.pump(const Duration(seconds: 3));
    visible.value = false;
    await tester.pump();
    visible.value = true;
    await tester.pump();
    expect(calls, 2);
    expect(find.text('v1'), findsOneWidget);
    expect(find.byType(OlLoadingCard), findsNothing);
    pending!.complete('v2');
    await tester.pump();
    await tester.pump();
    expect(find.text('v2'), findsOneWidget);

    // Refresh gagal → data lama tetap, tanpa kartu error.
    await tester.pump(const Duration(seconds: 3));
    fail = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(calls, 3);
    expect(find.text('v2'), findsOneWidget);
    expect(find.byType(OlErrorCard), findsNothing);
  });
}
