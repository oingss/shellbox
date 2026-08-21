import 'dart:convert';
import 'dart:math';

import '../data/crypto_service.dart';
import 'secret_storage.dart';

/// Holds the AES-256 master key used by [CryptoService].
///
/// The key is generated once and persisted inside [SecretStorage]
/// (Android Keystore / Windows DPAPI); it never touches sqflite directly.
class MasterKey {
  MasterKey(this._storage);

  static const _masterKeyKey = 'shellbox_master_key_v1';

  final SecretStorage _storage;
  bool _loaded = false;
  List<int>? _keyBytes;

  Future<CryptoService> cryptoService() async {
    if (!_loaded) {
      await _loadOrCreate();
    }
    return CryptoService(_keyBytes!);
  }

  Future<void> _loadOrCreate() async {
    final existing = await _storage.read(_masterKeyKey);
    if (existing != null && existing.isNotEmpty) {
      _keyBytes = base64.decode(existing);
      _loaded = true;
      return;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _storage.write(_masterKeyKey, base64.encode(bytes));
    _keyBytes = bytes;
    _loaded = true;
  }
}