import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/server_repository.dart';
import '../models/server.dart';
import 'providers.dart';

/// Server list + the CRUD/settlement actions used by the home screen.
class HomeNotifier extends AsyncNotifier<List<Server>> {
  @override
  Future<List<Server>> build() async {
    final repo = await ref.read(serverRepositoryProvider.future);
    return repo.getAll();
  }

  ServerRepository? _repo;

  Future<ServerRepository> _repository() async {
    final existing = _repo;
    if (existing != null) {
      return existing;
    }
    final repo = await ref.read(serverRepositoryProvider.future);
    _repo = repo;
    return repo;
  }

  Future<void> refresh() async =>
      state = AsyncData(await (await _repository()).getAll());

  Future<void> saveOrUpdate(Server server) async {
    final repo = await _repository();
    if (server.id == null) {
      await repo.insert(server);
    } else {
      await repo.update(server);
    }
    await refresh();
  }

  Future<void> delete(int id) async {
    await (await _repository()).delete(id);
    await refresh();
  }

  Future<void> touchLastUsed(int id) async {
    await (await _repository()).updateLastUsed(id);
    await refresh();
  }
}

final homeProvider =
    AsyncNotifierProvider<HomeNotifier, List<Server>>(HomeNotifier.new);