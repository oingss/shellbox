import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/services/secret_storage.dart';

/// Backed by flutter_secure_storage, which uses the Android Keystore and the
/// Windows DPAPI (WinCrypt) under the hood.
class SecureStorageImpl implements SecretStorage {
  SecureStorageImpl()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) => _storage.write(
        key: key,
        value: value,
        aOptions: const AndroidOptions(encryptedSharedPreferences: true),
        wOptions: const WindowsOptions(),
      );

  @override
  Future<String?> read(String key) => _storage.read(
        key: key,
        aOptions: const AndroidOptions(encryptedSharedPreferences: true),
        wOptions: const WindowsOptions(),
      );

  @override
  Future<void> delete(String key) => _storage.delete(
        key: key,
        aOptions: const AndroidOptions(encryptedSharedPreferences: true),
        wOptions: const WindowsOptions(),
      );
}