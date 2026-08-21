import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Pure-Dart AES-256-GCM wrapper used to protect secrets before they hit the
/// database. The master key is generated and stored inside the platform secure
/// storage (Android Keystore / Windows DPAPI).
///
/// Ciphertext format matches the original Android app:
///   base64(IV) : base64(ciphertext ++ tag)
class CryptoService {
  CryptoService(this._secretBoxKey);

  final List<int> _secretBoxKey;

  static final _aes = AesGcm.with256bits();

  /// AES-GCM MAC (tag) length in bytes; the cryptography package exports the
  /// GCM tag but not a `macLength` getter on the cipher itself.
  static const _macLength = 16;

  /// Key must never be shared with sqflite; it only ever lives in memory and
  /// in the platform secure storage.
  static SecretKey _secretFromBytes(List<int> bytes) => SecretKey(bytes);

  Future<String> encrypt(String? plain) async {
    if (plain == null || plain.isEmpty) {
      return plain ?? '';
    }
    final iv = _aes.newNonce();
    final box = await _aes.encrypt(
      Uint8List.fromList(utf8.encode(plain)),
      secretKey: _secretFromBytes(_secretBoxKey),
      nonce: iv,
    );
    final ivB64 = base64.encode(iv);
    final payload = base64.encode([...box.cipherText, ...box.mac.bytes]);
    return '$ivB64:$payload';
  }

  Future<String> decrypt(String? encrypted) async {
    if (encrypted == null || encrypted.isEmpty) {
      return encrypted ?? '';
    }
    try {
      final parts = encrypted.split(':');
      if (parts.length != 2) {
        return encrypted;
      }
      final iv = base64.decode(parts[0]);
      final payload = base64.decode(parts[1]);
      final ctLen = payload.length - _macLength;
      if (ctLen < 0) {
        return encrypted;
      }
      final box = SecretBox(
        payload.sublist(0, ctLen),
        nonce: iv,
        mac: Mac(payload.sublist(ctLen)),
      );
      final clear = await _aes.decrypt(
        box,
        secretKey: _secretFromBytes(_secretBoxKey),
      );
      return utf8.decode(clear);
    } catch (_) {
      // Defensive: if the master key changed or the value could not be
      // decrypted we return it as-is rather than crashing callers.
      return encrypted;
    }
  }
}