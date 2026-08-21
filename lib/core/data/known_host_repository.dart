import '../models/known_host.dart';
import 'app_database.dart';

/// TOFU known-hosts persistence.
class KnownHostRepository {
  KnownHostRepository(this._db);

  final AppDatabase _db;

  Future<KnownHost?> findByHostPort(String hostPort) =>
      _db.getKnownHost(hostPort);

  Future<void> save(KnownHost host) => _db.upsertKnownHost(host);

  Future<void> delete(String hostPort) => _db.deleteKnownHost(hostPort);

  Future<List<KnownHost>> getAll() => _db.getAllKnownHosts();
}