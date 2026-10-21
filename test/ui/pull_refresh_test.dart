import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/ui/ui.dart';

import '../helpers.dart';

void main() {
  Future<void> pull(WidgetTester t) async {
    // Pola resmi uji RefreshIndicator: fling ke bawah lalu biarkan animasi & muat ulang selesai.
    await t.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
    await t.pump();
    await t.pump(const Duration(seconds: 1)); // animasi gulir selesai
    await t.pump(const Duration(seconds: 1)); // indikator muncul & onRefresh dipanggil
    await t.pump(const Duration(seconds: 1)); // muat ulang selesai, indikator hilang
  }

  testWidgets('layar turunan: tarik → semua OlAsync dimuat ulang + onRefresh', (t) async {
    var loads = 0, extra = 0;
    await t.pumpWidget(
      TestApp(
        scroll: false,
        child: OlDetailScaffold(
          title: 'Uji',
          onRefresh: () async => extra++,
          children: [
            OlAsync<int>(load: () async => ++loads, builder: (_, n, _) => [Text('data $n')]),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('data 1'), findsOneWidget);

    await pull(t);
    expect(loads, 2);
    expect(extra, 1);
    expect(find.text('data 2'), findsOneWidget);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  testWidgets('halaman tab: tarik → OlAsync dimuat ulang', (t) async {
    var loads = 0;
    await t.pumpWidget(
      TestApp(
        scroll: false,
        child: Scaffold(
          body: OlPageBody(
            header: const OlAppHeader(title: 'Tab'),
            children: [OlAsync<int>(load: () async => ++loads, builder: (_, n, _) => [Text('isi $n')])],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await pull(t);
    expect(loads, 2);
    expect(find.text('isi 2'), findsOneWidget);
  });
}
