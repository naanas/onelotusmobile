// Alat render layar ke PNG untuk cek visual tanpa perangkat.
// Jalankan: flutter test test_screens --dart-define=SHOT_DIR=/path/keluaran
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const shotDir = String.fromEnvironment('SHOT_DIR', defaultValue: 'build/shots');

Future<void> loadFonts() async {
  final phosphor =
      '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/phosphor_flutter-2.1.0/lib/fonts';
  final fonts = <String, List<String>>{
    'PlusJakartaSans': [
      for (final w in [400, 500, 600, 700, 800])
        'assets/fonts/PlusJakartaSans-$w.ttf',
    ],
    'JetBrainsMono': [
      'assets/fonts/JetBrainsMono-500.ttf',
      'assets/fonts/JetBrainsMono-700.ttf',
    ],
    'packages/phosphor_flutter/PhosphorRegular': ['$phosphor/Phosphor.ttf'],
    'packages/phosphor_flutter/PhosphorFill': ['$phosphor/Phosphor-Fill.ttf'],
    'packages/phosphor_flutter/PhosphorDuotone': [
      '$phosphor/Phosphor-Duotone.ttf',
    ],
  };
  for (final e in fonts.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

void phoneView(WidgetTester t) {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  t.view.padding = const FakeViewPadding(top: 24 * 2, bottom: 16 * 2);
  t.view.viewPadding = const FakeViewPadding(top: 24 * 2, bottom: 16 * 2);
  addTearDown(t.view.reset);
}

final shotKey = GlobalKey();

/// Bungkus root widget agar bisa dipotret.
Widget shootable(Widget child) => RepaintBoundary(key: shotKey, child: child);

Future<void> shot(WidgetTester t, String name) async {
  final ro =
      shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final img = await ro.toImage(pixelRatio: 2);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(shotDir).createSync(recursive: true);
    File('$shotDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}
