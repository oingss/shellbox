import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../data/known_host_repository.dart';
import '../data/server_repository.dart';
import '../services/app_services.dart';
import '../services/master_key.dart';
import '../ssh/key_loader.dart';
import '../ssh/known_hosts_verifier.dart';
import '../ssh/ssh_manager.dart';
import '../utils/terminal_settings_store.dart';

// ---------------------------------------------------------------------------
// Platform seam
// ---------------------------------------------------------------------------

/// Filled with the concrete [AppServices] in main();
/// core/state and features only use this container.
final appServicesProvider = Provider<AppServices>((ref) {
  throw UnimplementedError(
      'appServicesProvider must be overridden in main() before runApp');
});

// ---------------------------------------------------------------------------
// Persistence plumbing
// ---------------------------------------------------------------------------

final masterKeyProvider =
    Provider((ref) => MasterKey(ref.watch(appServicesProvider).secretStorage));

final cryptoServiceProvider = FutureProvider((ref) async {
  final masterKey = ref.watch(masterKeyProvider);
  return masterKey.cryptoService();
});

final appDatabaseProvider = FutureProvider((ref) async {
  final db = await AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final serverRepositoryProvider = FutureProvider((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final crypto = await ref.watch(cryptoServiceProvider.future);
  return ServerRepository(db, crypto);
});

final knownHostRepositoryProvider = FutureProvider((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return KnownHostRepository(db);
});

// ---------------------------------------------------------------------------
// SSH plumbing
// ---------------------------------------------------------------------------

final keyLoaderProvider = Provider((ref) =>
    KeyLoader(ref.watch(appServicesProvider).filePicker));

final knownHostsVerifierProvider = FutureProvider((ref) async {
  final repo = await ref.watch(knownHostRepositoryProvider.future);
  return KnownHostsVerifier(repo);
});

final sshManagerProvider = FutureProvider((ref) async {
  final verifier = await ref.watch(knownHostsVerifierProvider.future);
  return SshManager(ref.watch(keyLoaderProvider), verifier);
});

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

/// Raw SharedPreferences; the terminal settings store + vkey layout read it.
final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

/// Assigned in main() after `SharedPreferences.getInstance()` so consumers can
/// read settings synchronously.
final terminalSettingsProvider = Provider<TerminalSettingsStore>((ref) =>
    throw UnimplementedError(
        'terminalSettingsProvider must be overridden in main()'));