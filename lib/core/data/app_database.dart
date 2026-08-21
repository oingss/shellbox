import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/known_host.dart';
import '../models/port_forward_rule.dart';
import '../models/server.dart';
import '../models/server_common.dart';

/// SQLite layer mirroring the original Room schema (database version 3).
///
/// The same code runs on Android (sqflite) and Windows
/// (sqflite_common_ffi); main() sets [overrideFactory] when a specific engine
/// must be used.
class AppDatabase {
  AppDatabase(this._db);

  final sqflite.Database _db;

  static const dbName = 'shellbox.db';
  static const dbVersion = 3;

  static sqflite.DatabaseFactory? overrideFactory;

  static Future<AppDatabase> open() async {
    final factory = overrideFactory ?? _defaultFactory();
    final base = await factory.getDatabasesPath();
    final path = p.join(base, dbName);

    final db = await factory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: dbVersion,
        onCreate: _onCreate,
      ),
    );
    return AppDatabase(db);
  }

  static sqflite.DatabaseFactory _defaultFactory() {
    if (Platform.isWindows) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return sqflite.databaseFactory;
  }

  static Future<void> _onCreate(sqflite.Database db, int version) async {
    await db.execute('''
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

    await db.execute('''
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
    final rows = await _db.query(
      'servers',
      orderBy: 'lastUsedAt IS NULL, lastUsedAt DESC, createdAt DESC',
    );
    return rows.map(_serverFromRow).toList();
  }

  Future<Server?> getServerById(int id) async {
    final rows = await _db.query('servers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _serverFromRow(rows.first);
  }

  Future<int> insertServer(Server server) =>
      _db.insert('servers', _serverToRow(server));

  Future<void> updateServer(Server server) async {
    await _db.update('servers', _serverToRow(server),
        where: 'id = ?', whereArgs: [server.id]);
  }

  Future<void> updateLastUsed(int id) async {
    await _db.update(
      'servers',
      {'lastUsedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteServer(int id) async {
    await _db.delete('servers', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Known hosts (TOFU)

  Future<KnownHost?> getKnownHost(String hostPort) async {
    final rows = await _db.query('known_hosts',
        where: 'hostPort = ?', whereArgs: [hostPort]);
    return rows.isEmpty ? null : KnownHost.fromDb(rows.first);
  }

  Future<void> upsertKnownHost(KnownHost host) async {
    await _db.insert('known_hosts', host.toDb(),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future<void> deleteKnownHost(String hostPort) async {
    await _db.delete('known_hosts',
        where: 'hostPort = ?', whereArgs: [hostPort]);
  }

  Future<List<KnownHost>> getAllKnownHosts() async {
    final rows = await _db.query('known_hosts', orderBy: 'hostPort');
    return rows.map(KnownHost.fromDb).toList();
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

  Server _serverFromRow(Map<String, Object?> row) => Server.fromDb(
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

  sqflite.Database get raw => _db;
  Future<void> close() => _db.close();
}