import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'shot.dart';

void main() {
  testWidgets('frame splash lotus', (t) async {
    t.view.physicalSize = const Size(600, 240);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    late LottieComposition comp;
    await t.runAsync(() async {
      comp = await AssetLottie('assets/lottie/an_splash_lotus.json').load();
    });
    await t.pumpWidget(
      shootable(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: const Color(0xFF0C4A6E),
            child: Row(
              children: [
                for (final p in [0.0, 0.25, 0.5, 0.75, 1.0])
                  Expanded(
                    child: Lottie(
                      composition: comp,
                      animate: false,
                      frameRate: FrameRate.max,
                      controller: AlwaysStoppedAnimation(p),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await shot(t, 'lottie_splash_frames');
  });
}
