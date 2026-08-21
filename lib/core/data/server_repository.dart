import '../models/server.dart';
import '../models/server_common.dart';
import 'app_database.dart';
import 'crypto_service.dart';

/// Reads/writes servers, encrypting secret fields transparently so the rest of
/// the app works with plaintext values.
class ServerRepository {
  ServerRepository(this._db, this._crypto);

  final AppDatabase _db;
  final CryptoService _crypto;

  Future<List<Server>> getAll() async {
    final raw = await _db.getAllServers();
    final out = <Server>[];
    for (final s in raw) {
      out.add(await _decrypt(s));
    }
    return out;
  }

  Future<Server?> getById(int id) async {
    final s = await _db.getServerById(id);
    return s == null ? null : _decrypt(s);
  }

  Future<int> insert(Server server) async {
    return _db.insertServer(await _encrypt(server));
  }

  Future<void> update(Server server) async {
    await _db.updateServer(await _encrypt(server));
  }

  Future<void> updateLastUsed(int id) => _db.updateLastUsed(id);

  Future<void> delete(int id) => _db.deleteServer(id);

  // ---------------------------------------------------------------------------

  Future<Server> _encrypt(Server s) async {
    // Private-key passphrase only ever exists when TEXT-pasted; a file-loaded
    // key uses its own embedded encryption.
    final needKeyEncryption = s.authType == AuthType.privateKey &&
        s.privateKeySource == PrivateKeySource.text;

    return s.copyWith(
      password: await _crypto.encrypt(s.password),
      privateKeyValue: needKeyEncryption
          ? await _crypto.encrypt(s.privateKeyValue)
          : s.privateKeyValue,
      privateKeyPassphrase: needKeyEncryption
          ? await _crypto.encrypt(s.privateKeyPassphrase)
          : s.privateKeyPassphrase,
    );
  }

  Future<Server> _decrypt(Server s) async {
    final needKeyDecryption = s.authType == AuthType.privateKey &&
        s.privateKeySource == PrivateKeySource.text;

    return s.copyWith(
      password: await _crypto.decrypt(s.password),
      privateKeyValue: needKeyDecryption
          ? await _crypto.decrypt(s.privateKeyValue)
          : s.privateKeyValue,
      privateKeyPassphrase: needKeyDecryption
          ? await _crypto.decrypt(s.privateKeyPassphrase)
          : s.privateKeyPassphrase,
    );
  }
}