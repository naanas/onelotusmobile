import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/pasien/booking/payment_channel_picker.dart';

/// Semua logo kanal di assets/payment/ bisa di-parse flutter_svg & punya ukuran.
/// Set LOGO_RENDER_DIR untuk menyimpan pratinjau PNG.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final MapEntry(key: k, value: path) in paymentLogoAssets.entries) {
    test('logo $k terbaca', () async {
      final info = await vg.loadPicture(SvgStringLoader(await rootBundle.loadString(path)), null);
      expect(info.size.width, greaterThan(0));
      expect(info.size.height, greaterThan(0));
      final out = Platform.environment['LOGO_RENDER_DIR'];
      if (out != null) {
        const w = 320.0;
        final h = w * info.size.height / info.size.width;
        final rec = ui.PictureRecorder();
        final canvas = ui.Canvas(rec)
          ..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src)
          ..scale(w / info.size.width);
        canvas.drawPicture(info.picture);
        final img = await rec.endRecording().toImage(w.ceil(), h.ceil());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$k.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
      info.picture.dispose();
    });
  }
}
