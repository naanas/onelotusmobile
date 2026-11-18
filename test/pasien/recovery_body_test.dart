import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/pasien/beranda/recovery_body.dart';
import 'package:onelotus_staff/theme/app_theme.dart';
import 'package:onelotus_staff/ui/body_map/body_map_data.dart';
import 'package:onelotus_staff/ui/body_map/body_map_selection.dart';

void main() {
  Future<void> pump(WidgetTester tester, Map<String, BodyMode> areas) async {
    await tester.runAsync(BodyMapData.load);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOlTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: RecoveryBody(areas: areas)),
        ),
      ),
    );
    // FutureBuilder menunggu aset di zona async asli.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('siluet depan & belakang punya tinggi (tidak kosong)', (tester) async {
    await pump(tester, const {'knees:right': BodyMode.treated});
    final paints = find.descendant(of: find.byType(RecoveryBody), matching: find.byType(CustomPaint));
    final sizes = [for (final e in paints.evaluate()) tester.getSize(find.byWidget(e.widget))];
    expect(sizes.where((s) => s.height > 100 && s.width > 50).length, greaterThanOrEqualTo(2));
    expect(find.textContaining('Lutut kanan'), findsOneWidget);
  });

  testWidgets('belum ada data: label menunggu + tombol jadwalkan', (tester) async {
    await pump(tester, const {});
    expect(find.text('Menunggu asesmen awal'), findsOneWidget);
    expect(find.text('Jadwalkan sesi pertama'), findsOneWidget);
  });
}
