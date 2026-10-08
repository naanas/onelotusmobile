import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/ui/ui.dart';

import '../helpers.dart';

/// §9: kontrol interaktif harus punya label sendiri untuk TalkBack/VoiceOver,
/// juga saat berada di dalam baris daftar yang berisi teks lain.
void main() {
  testWidgets('kontrol di dalam baris tetap punya label & status sendiri', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(
      TestApp(
        child: Column(
          children: [
            OlListItem(
              title: 'Simulasi offline',
              subtitle: 'Mode mock',
              trailing: OlToggle(
                value: true,
                onChanged: (_) {},
                semanticLabel: 'Simulasi offline',
              ),
            ),
            OlListItem(
              title: 'Status sinkron',
              trailing: SyncIndicator(
                status: const SyncOffline(2),
                onTap: () {},
              ),
            ),
            const OlChip(label: 'Adjustment', selected: true),
            OlCheckbox(
              label: 'Ingat perangkat ini',
              value: true,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    final toggle = t.getSemantics(find.byType(OlToggle));
    expect(toggle.label, 'Simulasi offline');
    expect(toggle.flagsCollection.isToggled, Tristate.isTrue);

    expect(
      t.getSemantics(find.byType(SyncIndicator)).label,
      'Status sinkron: Offline — 2 catatan menunggu',
    );
    final chip = t.getSemantics(find.byType(OlChip));
    expect(chip.label, 'Adjustment');
    expect(chip.flagsCollection.isSelected, Tristate.isTrue);
    expect(
      t.getSemantics(find.byType(OlCheckbox)).label,
      'Ingat perangkat ini',
    );

    // Teks baris tidak hilang.
    expect(find.bySemanticsLabel(RegExp('Mode mock')), findsOneWidget);
    h.dispose();
  });
}
