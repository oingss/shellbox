/// Platform-agnostic secret storage abstraction (Android Keystore /
/// Windows DPAPI via flutter_secure_storage).
abstract class SecretStorage {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}