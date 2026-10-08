import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/ui/body_map/body_map.dart';
import 'package:onelotus_staff/ui/body_map/body_map_data.dart';

import '../helpers.dart';

void main() {
  group('BodyMapSelection', () {
    test(
      'ketuk: pilih, ketuk lagi mode sama = hapus, mode lain = ganti mode',
      () {
        var s = const BodyMapSelection();
        s = s.toggle('deltoids:right', BodyMode.treated);
        expect(s.modeOf('deltoids:right'), BodyMode.treated);
        s = s.toggle('deltoids:right', BodyMode.calming);
        expect(s.modeOf('deltoids:right'), BodyMode.calming);
        s = s.toggle('deltoids:right', BodyMode.calming);
        expect(s.modeOf('deltoids:right'), isNull);
      },
    );

    test('kiri + kanan mode sama digabung "(kedua sisi)"; beda mode tidak', () {
      const s = BodyMapSelection({
        'lower-back:left': BodyMode.treated,
        'lower-back:right': BodyMode.treated,
        'deltoids:right': BodyMode.treated,
        'quadriceps:left': BodyMode.treated,
        'quadriceps:right': BodyMode.calming,
        'neck:common': BodyMode.calming,
      });
      final chips = s.chips().map((c) => c.text).toList();
      expect(chips, [
        'Lumbal (kedua sisi)',
        'Bahu kanan',
        'Paha depan kiri',
        'Penenang: paha depan kanan',
        'Penenang: leher',
      ]);
      expect(s.chips().first.keys, ['lower-back:left', 'lower-back:right']);
    });

    test('hapus lewat chip gabungan menghapus kedua sisi', () {
      const s = BodyMapSelection({
        'calves:left': BodyMode.calming,
        'calves:right': BodyMode.calming,
      });
      final chip = s.chips().single;
      expect(s.removeAll(chip.keys).areas, isEmpty);
    });

    test('label area', () {
      expect(bodyAreaLabel('upper-back:left'), 'Punggung atas kiri');
      expect(bodyAreaLabel('head:common'), 'Kepala');
    });
  });

  test('aset peta tubuh: area depan & belakang, kunci sesuai _parts.json', () {
    final data = BodyMapData.parse(
      File('assets/body/bodymap_paths.json').readAsStringSync(),
    );
    expect(data.front.muscles, hasLength(88));
    expect(data.back.muscles, hasLength(69));
    final keys = {
      ...data.front.muscles.map((m) => m.key),
      ...data.back.muscles.map((m) => m.key),
    };
    expect(
      keys.every((k) => RegExp(r'^[a-z-]+:(left|right|common)$').hasMatch(k)),
      isTrue,
    );
    expect(
      keys,
      containsAll(['lower-back:left', 'deltoids:right', 'quadriceps:right']),
    );
    // Bahu ada di kedua tampak → satu kunci menandai keduanya.
    expect(data.front.muscles.any((m) => m.key == 'deltoids:right'), isTrue);
    expect(data.back.muscles.any((m) => m.key == 'deltoids:right'), isTrue);
    // Hit-test: tengah suatu otot mengenai otot itu.
    final m = data.front.muscles.firstWhere((m) => m.key == 'chest:left');
    expect(data.front.hit(m.bounds.center)?.key, 'chest:left');
    expect(data.front.hit(const Offset(5, 5)), isNull);
  });

  testWidgets('BodyMap: ketuk otot di siluet menandai & memunculkan chip', (
    t,
  ) async {
    var sel = const BodyMapSelection();
    final bytes = File('assets/body/bodymap_paths.json').readAsStringSync();
    final data = BodyMapData.parse(bytes);
    final target = data.front.muscles.firstWhere((m) => m.key == 'chest:left');
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      TestApp(
        child: StatefulBuilder(
          builder: (context, set) => Padding(
            padding: const EdgeInsets.all(20),
            child: BodyMap(
              data: data,
              selection: sel,
              mode: BodyMode.treated,
              onChanged: (v) => set(() => sel = v),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    // Siluet depan = CustomPaint pertama di dalam BodyMap.
    final paint = find.byKey(const ValueKey('bodymap-Depan'));
    final box = t.getRect(paint);
    final scale = box.width / data.front.viewBox.width;
    await t.tapAt(box.topLeft + target.bounds.center * scale);
    await t.pump(const Duration(milliseconds: 400));
    expect(sel.modeOf('chest:left'), BodyMode.treated);
    expect(find.text('Dada kiri'), findsWidgets);
    await t.pump(const Duration(seconds: 2));
  });
}
