import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/ui/ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('daftar panjang: tombol Ke atas muncul setelah digulir jauh, ketuk → kembali ke atas', (t) async {
    await t.pumpWidget(
      TestApp(
        scroll: false,
        child: OlPageBody(
          pinnedHeader: true,
          backToTop: true,
          header: const OlAppHeader(title: 'Daftar'),
          children: [for (var i = 0; i < 120; i++) SizedBox(height: 80, child: Text('Baris $i'))],
        ),
      ),
    );
    await t.pumpAndSettle();
    final btn = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Kembali ke atas');
    double pos() => t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    bool shown() => t.widget<AnimatedOpacity>(find.ancestor(of: btn, matching: find.byType(AnimatedOpacity)).first).opacity == 1;

    expect(shown(), isFalse);
    await t.drag(find.byType(ListView), const Offset(0, -4000));
    await t.pumpAndSettle();
    expect(shown(), isTrue);
    expect(pos(), greaterThan(2000));

    await t.tap(btn);
    await t.pumpAndSettle();
    expect(pos(), 0);
    expect(shown(), isFalse);
  });
}
