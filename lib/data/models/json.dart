/// Helper parsing JSON API (snake_case, tanggal ISO-8601).
DateTime? parseDate(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

String? formatDate(DateTime? d) => d?.toUtc().toIso8601String();

/// Tanggal tanpa jam (`2026-10-06`), mis. tanggal lahir.
String? formatDay(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int? parseInt(Object? v) => switch (v) {
  int i => i,
  num n => n.toInt(),
  String s => int.tryParse(s),
  _ => null,
};

double? parseDouble(Object? v) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};

List<String> parseStrings(Object? v) => [
  for (final e in (v as List?) ?? const []) e.toString(),
];
