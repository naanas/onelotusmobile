import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/features/dev/component_gallery_page.dart';

import '../helpers.dart';

void main() {
  for (final scale in [1.0, 1.3, 1.6]) {
    testWidgets('Galeri komponen tampil tanpa overflow di text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        TestApp(scroll: false, child: const ComponentGalleryPage()),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      // Gulir sampai bawah: overflow apa pun akan menggagalkan tes.
      for (var i = 0; i < 60; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: 'gulir ke-$i');
      }
      expect(find.text('regular · fill · duotone'), findsOneWidget);
    });
  }
}
