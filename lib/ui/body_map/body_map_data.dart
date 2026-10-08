import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

class BodyMuscle {
  BodyMuscle(this.key, this.path) : bounds = path.getBounds();

  /// `slug:sisi` (left/right/common).
  final String key;
  final Path path;
  final Rect bounds;
}

class BodyView {
  BodyView({required this.viewBox, required this.outline, required this.hair, required this.muscles});

  final Rect viewBox;
  final Path outline;
  final Path? hair;
  final List<BodyMuscle> muscles;

  /// Otot di titik [p] (koordinat viewBox). Rambut & garis luar tidak bisa dipilih.
  BodyMuscle? hit(Offset p) {
    for (final m in muscles.reversed) {
      if (m.bounds.contains(p) && m.path.contains(p)) return m;
    }
    return null;
  }
}

class BodyMapData {
  BodyMapData({required this.front, required this.back});

  final BodyView front;
  final BodyView back;

  static const asset = 'assets/body/bodymap_paths.json';
  static Future<BodyMapData>? _cache;

  /// Dimuat & di-parse sekali per aplikasi.
  static Future<BodyMapData> load([AssetBundle? bundle]) =>
      _cache ??= (bundle ?? rootBundle).loadString(asset).then(parse);

  static BodyMapData parse(String json) {
    final d = jsonDecode(json) as Map<String, dynamic>;
    BodyView view(Map<String, dynamic> v) {
      final vb = (v['viewBox'] as List).cast<num>();
      return BodyView(
        viewBox: Rect.fromLTWH(vb[0].toDouble(), vb[1].toDouble(), vb[2].toDouble(), vb[3].toDouble()),
        outline: parseSvgPathData(v['outline'] as String),
        hair: v['hair'] == null ? null : parseSvgPathData(v['hair'] as String),
        muscles: [
          for (final m in (v['muscles'] as List).cast<Map<String, dynamic>>())
            BodyMuscle(m['k'] as String, parseSvgPathData(m['d'] as String)),
        ],
      );
    }

    return BodyMapData(front: view(d['front'] as Map<String, dynamic>), back: view(d['back'] as Map<String, dynamic>));
  }
}
