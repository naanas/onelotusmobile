import 'package:flutter/foundation.dart';

/// Mode tandai (D.2b): ditangani (biru) atau penenang (oranye).
enum BodyMode { treated, calming }

/// Nama klinis per slug (react-native-body-highlighter → istilah Indonesia).
const bodyAreaNames = {
  'chest': 'Dada',
  'abs': 'Perut',
  'obliques': 'Perut samping',
  'biceps': 'Lengan atas depan',
  'triceps': 'Lengan atas belakang',
  'forearm': 'Lengan bawah',
  'deltoids': 'Bahu',
  'trapezius': 'Trapezius',
  'neck': 'Leher',
  'head': 'Kepala',
  'hands': 'Tangan',
  'adductors': 'Paha dalam',
  'quadriceps': 'Paha depan',
  'hamstring': 'Paha belakang',
  'knees': 'Lutut',
  'tibialis': 'Tulang kering',
  'calves': 'Betis',
  'ankles': 'Pergelangan kaki',
  'feet': 'Telapak kaki',
  'gluteal': 'Bokong',
  'upper-back': 'Punggung atas',
  'lower-back': 'Lumbal',
};

const _sideNames = {'left': ' kiri', 'right': ' kanan', 'common': ''};

/// "deltoids:right" → "Bahu kanan".
String bodyAreaLabel(String key) {
  final [slug, side] = key.split(':');
  return '${bodyAreaNames[slug] ?? slug}${_sideNames[side] ?? ''}';
}

/// Satu chip area: kiri+kanan dengan mode sama digabung jadi "(kedua sisi)".
@immutable
class BodyAreaChip {
  const BodyAreaChip({
    required this.keys,
    required this.mode,
    required this.label,
  });

  final List<String> keys;
  final BodyMode mode;
  final String label;

  String get id => '${mode.name}|${keys.join(',')}';

  /// Teks chip: penenang diberi awalan (TR-04).
  String get text =>
      mode == BodyMode.calming ? 'Penenang: ${label.toLowerCase()}' : label;
}

/// Pilihan area tubuh — tak berubah (immutable), aman dipakai di setState.
@immutable
class BodyMapSelection {
  const BodyMapSelection([this.areas = const {}]);

  /// Kunci `slug:sisi` → mode. Area yang sama di tampak depan & belakang memakai kunci yang sama.
  final Map<String, BodyMode> areas;

  BodyMode? modeOf(String key) => areas[key];

  /// Ketuk area: bila sudah bermode sama → hapus; selain itu → set ke mode ini.
  BodyMapSelection toggle(String key, BodyMode mode) {
    final next = Map.of(areas);
    if (next[key] == mode) {
      next.remove(key);
    } else {
      next[key] = mode;
    }
    return BodyMapSelection(next);
  }

  BodyMapSelection removeAll(Iterable<String> keys) => BodyMapSelection({
    for (final e in areas.entries)
      if (!keys.contains(e.key)) e.key: e.value,
  });

  List<String> keysOf(BodyMode mode) => [
    for (final e in areas.entries)
      if (e.value == mode) e.key,
  ];

  /// Chip untuk ditampilkan, urut sesuai urutan pilih.
  List<BodyAreaChip> chips() {
    final out = <BodyAreaChip>[];
    final seen = <String>{};
    for (final MapEntry(key: k, value: m) in areas.entries) {
      if (seen.contains(k)) continue;
      final [slug, side] = k.split(':');
      final other = switch (side) {
        'left' => '$slug:right',
        'right' => '$slug:left',
        _ => null,
      };
      if (other != null && areas[other] == m) {
        seen.addAll([k, other]);
        out.add(
          BodyAreaChip(
            keys: [k, other],
            mode: m,
            label: '${bodyAreaNames[slug] ?? slug} (kedua sisi)',
          ),
        );
      } else {
        seen.add(k);
        out.add(BodyAreaChip(keys: [k], mode: m, label: bodyAreaLabel(k)));
      }
    }
    return out;
  }
}
