import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Database lokal (§8): outbox sinkron, draf autosave, cache baca offline.
// TODO(keamanan): enkripsi at-rest (UM-07: "data lokal yang belum sinkron tetap disimpan
// terenkripsi") — rencana: sqflite_sqlcipher dengan kunci di flutter_secure_storage.
class LocalDb {
  LocalDb(this.db);

  final Database db;

  static const _version = 1;

  static Future<LocalDb> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'onelotus.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onCreate: (db, _) => createSchema(db),
      ),
    );
    return LocalDb(db);
  }

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE outbox (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        lane TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        base_version INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        next_attempt_at INTEGER NOT NULL,
        last_error TEXT,
        last_error_ref TEXT,
        server_payload TEXT,
        server_version INTEGER
      )''');
    await db.execute(
      'CREATE INDEX outbox_due ON outbox(status, next_attempt_at)',
    );
    await db.execute('CREATE INDEX outbox_entity ON outbox(kind, entity_id)');
    await db.execute('''
      CREATE TABLE drafts (
        key TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE cache (
        key TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL
      )''');
  }
}
