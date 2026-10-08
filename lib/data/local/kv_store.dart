import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Penyimpanan JSON berkunci — dipakai untuk draf autosave & cache baca offline.
abstract interface class KvStore {
  Future<void> put(String key, Object? json);
  Future<({Object? json, DateTime at})?> get(String key);
  Future<void> delete(String key);
  Future<List<String>> keys({String? prefix});
}

class SqfliteKvStore implements KvStore {
  SqfliteKvStore(this.db, this.table);

  final Database db;

  /// `drafts` atau `cache`.
  final String table;

  String get _timeCol => table == 'cache' ? 'fetched_at' : 'updated_at';

  @override
  Future<void> put(String key, Object? json) => db.insert(table, {
    'key': key,
    'payload': jsonEncode(json),
    _timeCol: DateTime.now().millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<({Object? json, DateTime at})?> get(String key) async {
    final rows = await db.query(
      table,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (
      json: jsonDecode(rows.first['payload']! as String),
      at: DateTime.fromMillisecondsSinceEpoch(rows.first[_timeCol]! as int),
    );
  }

  @override
  Future<void> delete(String key) =>
      db.delete(table, where: 'key = ?', whereArgs: [key]);

  @override
  Future<List<String>> keys({String? prefix}) async {
    final rows = prefix == null
        ? await db.query(table, columns: ['key'])
        : await db.query(
            table,
            columns: ['key'],
            where: 'key LIKE ?',
            whereArgs: ['$prefix%'],
          );
    return [for (final r in rows) r['key']! as String];
  }
}

class MemoryKvStore implements KvStore {
  final _data = <String, ({Object? json, DateTime at})>{};

  @override
  Future<void> put(String key, Object? json) async =>
      _data[key] = (json: jsonDecode(jsonEncode(json)), at: DateTime.now());

  @override
  Future<({Object? json, DateTime at})?> get(String key) async => _data[key];

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<List<String>> keys({String? prefix}) async => [
    for (final k in _data.keys)
      if (prefix == null || k.startsWith(prefix)) k,
  ];
}
