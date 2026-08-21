import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/known_host.dart';
import '../models/port_forward_rule.dart';
import '../models/server.dart';
import '../models/server_common.dart';

/// SQLite layer mirroring the original Room schema (database version 3).
///
/// Uses `package:sqlite3` directly (the same underlying native library that
/// `sqlite3_flutter_libs` bundles for each platform) rather than going
/// through `sqflite`/`sqflite_common_ffi`. That combination was replaced
/// after it turned out to pull in `package:jni` transitively on the
/// dependency graph — `jni` tries to spawn an actual JVM on non-Android
/// desktop targets (see https://pub.dev/documentation/jni/latest/, "a new
/// JVM needs to be spawned on flutter desktop & standalone targets"), which
/// is almost certainly what caused the silent, no-log, exit-code-c000041d
/// crash during Windows startup — the crash happened before any Dart-side
/// code (not even `main()`) had a chance to log anything, consistent with
/// a native library failing to initialize during process/DLL load.
/// `sqlite3` + `sqlite3_flutter_libs` has no such dependency and is the
/// combination the sqlite3_flutter_libs package itself is designed for.
class AppDatabase {
  AppDatabase(this._db);

  final Database _db;

  static const dbName = 'shellbox.db';
  static const dbVersion = 3;

  /// Test/dev hook: if set, `open()` uses this path instead of the
  /// platform default (e.g. an in-memory or temp-dir database).
  static String? overridePath;

  static Future<AppDatabase> open() async {
    final path = overridePath ?? await _defaultPath();
    final db = sqlite3.open(path);
    final currentVersion = db.userVersion;
    if (currentVersion == 0) {
      _onCreate(db);
      db.userVersion = dbVersion;
    }
    // NOTE: no migration branches yet since this is a fresh rewrite: bump
    // this block with `ALTER TABLE`/etc. steps if dbVersion is ever
    // incremented against an already-shipped schema.
    return AppDatabase(db);
  }

  static Future<String> _defaultPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, dbName);
  }

  static void _onCreate(Database db) {
    db.execute('''
CREATE TABLE servers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  host TEXT NOT NULL,
  port INTEGER NOT NULL,
  username TEXT NOT NULL,
  authType TEXT NOT NULL,
  password TEXT,
  privateKeySource TEXT,
  privateKeyValue TEXT,
  privateKeyPassphrase TEXT,
  createdAt INTEGER NOT NULL,
  lastUsedAt INTEGER,
  portForwardRules TEXT NOT NULL DEFAULT '[]'
);''');

    db.execute('''
CREATE TABLE known_hosts (
  hostPort TEXT PRIMARY KEY,
  keyType TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  firstSeenAt INTEGER NOT NULL
);''');
  }

  // ---------------------------------------------------------------------------
  // Servers

  Future<List<Server>> getAllServers() async {
    final result = _db.select(
      'SELECT * FROM servers ORDER BY lastUsedAt IS NULL, lastUsedAt DESC, createdAt DESC',
    );
    return result.map(_serverFromRow).toList();
  }

  Future<Server?> getServerById(int id) async {
    final result =
        _db.select('SELECT * FROM servers WHERE id = ?', [id]);
    return result.isEmpty ? null : _serverFromRow(result.first);
  }

  Future<int> insertServer(Server server) async {
    final row = _serverToRow(server);
    final columns = row.keys.join(', ');
    final placeholders = List.filled(row.length, '?').join(', ');
    _db.execute(
      'INSERT INTO servers ($columns) VALUES ($placeholders)',
      row.values.toList(),
    );
    return _db.lastInsertRowId;
  }

  Future<void> updateServer(Server server) async {
    final row = _serverToRow(server)..remove('id');
    final setClause = row.keys.map((k) => '$k = ?').join(', ');
    _db.execute(
      'UPDATE servers SET $setClause WHERE id = ?',
      [...row.values, server.id],
    );
  }

  Future<void> updateLastUsed(int id) async {
    _db.execute(
      'UPDATE servers SET lastUsedAt = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  Future<void> deleteServer(int id) async {
    _db.execute('DELETE FROM servers WHERE id = ?', [id]);
  }

  // ---------------------------------------------------------------------------
  // Known hosts (TOFU)

  Future<KnownHost?> getKnownHost(String hostPort) async {
    final result = _db.select(
      'SELECT * FROM known_hosts WHERE hostPort = ?',
      [hostPort],
    );
    return result.isEmpty ? null : KnownHost.fromDb(result.first);
  }

  Future<void> upsertKnownHost(KnownHost host) async {
    final row = host.toDb();
    final columns = row.keys.join(', ');
    final placeholders = List.filled(row.length, '?').join(', ');
    final updateClause =
        row.keys.map((k) => '$k = excluded.$k').join(', ');
    _db.execute(
      'INSERT INTO known_hosts ($columns) VALUES ($placeholders) '
      'ON CONFLICT(hostPort) DO UPDATE SET $updateClause',
      row.values.toList(),
    );
  }

  Future<void> deleteKnownHost(String hostPort) async {
    _db.execute('DELETE FROM known_hosts WHERE hostPort = ?', [hostPort]);
  }

  Future<List<KnownHost>> getAllKnownHosts() async {
    final result =
        _db.select('SELECT * FROM known_hosts ORDER BY hostPort');
    return result.map(KnownHost.fromDb).toList();
  }

  // ---------------------------------------------------------------------------

  Map<String, Object?> _serverToRow(Server s) => {
        if (s.id != null) 'id': s.id,
        'name': s.name,
        'host': s.host,
        'port': s.port,
        'username': s.username,
        'authType': s.authType.name,
        'password': s.password,
        'privateKeySource': s.privateKeySource?.name,
        'privateKeyValue': s.privateKeyValue,
        'privateKeyPassphrase': s.privateKeyPassphrase,
        'createdAt': s.createdAt.millisecondsSinceEpoch,
        'lastUsedAt': s.lastUsedAt?.millisecondsSinceEpoch,
        'portForwardRules': PortForwardRule.toJsonList(s.portForwardRules),
      };

  Server _serverFromRow(Row row) => Server.fromDb(
        id: row['id'] as int?,
        name: row['name'] as String,
        host: row['host'] as String,
        port: (row['port'] as num).toInt(),
        username: row['username'] as String,
        authType: AuthType.values.firstWhere(
          (t) => t.name == row['authType'],
          orElse: () => AuthType.password,
        ),
        password: row['password'] as String?,
        privateKeySource: row['privateKeySource'] == null
            ? null
            : PrivateKeySource.values.firstWhere(
                (t) => t.name == row['privateKeySource'],
                orElse: () => PrivateKeySource.file,
              ),
        privateKeyValue: row['privateKeyValue'] as String?,
        privateKeyPassphrase: row['privateKeyPassphrase'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row['createdAt'] as num).toInt(),
        ),
        lastUsedAt: row['lastUsedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (row['lastUsedAt'] as num).toInt(),
              ),
        portForwardRulesJson: row['portForwardRules'] as String? ?? '[]',
      );

  Database get raw => _db;
  Future<void> close() async => _db.dispose();
}
