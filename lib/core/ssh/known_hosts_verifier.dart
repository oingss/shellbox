import 'dart:convert';

import '../data/known_host_repository.dart';
import '../models/known_host.dart';

/// Classification of one host-key verification.
sealed class VerifyOutcome {
  const VerifyOutcome();
}

/// Presented key matched the stored fingerprint.
final class Trusted extends VerifyOutcome {
  const Trusted();
}

/// New host: its key is now trusted and persisted.
final class NewHostTrusted extends VerifyOutcome {
  const NewHostTrusted();
}

/// Presented key differs from the recorded one.
final class Mismatch extends VerifyOutcome {
  const Mismatch({
    required this.storedFingerprint,
    required this.actualFingerprint,
  });
  final String storedFingerprint;
  final String actualFingerprint;
}

/// Trust-On-First-Use host verification, fed directly by dartssh2's
/// `onVerifyHostKey` handler, which already hands us the key `type` plus an
/// OpenSSH-style `SHA256:...` UTF-8 fingerprint. We persist and compare that
/// fingerprint instead of re-deriving bytes ourselves, keeping us in sync with
/// how dartssh2 computes it.
class KnownHostsVerifier {
  KnownHostsVerifier(this._repository);

  final KnownHostRepository _repository;

  /// Returns true to continue connecting, false to abort (Mismatch).
  /// The [onOutcome] callback can be invoked to expose the classification to
  /// the UI (e.g. to show the "host key changed" dialog) without breaking the
  /// sync bool contract.
  Future<bool> handleHostKey({
    required String host,
    required int port,
    required String keyType,
    required List<int> fingerprint,
    void Function(VerifyOutcome outcome)? onOutcome,
  }) async {
    final hostPort = '$host:$port';
    final fingerprintText = utf8.decode(fingerprint);

    final stored = await _repository.findByHostPort(hostPort);
    if (stored == null) {
      await _repository.save(KnownHost(
        hostPort: hostPort,
        keyType: keyType,
        fingerprint: fingerprintText,
        firstSeenAt: DateTime.now(),
      ));
      onOutcome?.call(const NewHostTrusted());
      return true;
    }

    if (stored.fingerprint == fingerprintText) {
      onOutcome?.call(const Trusted());
      return true;
    }

    onOutcome?.call(Mismatch(
      storedFingerprint: stored.fingerprint,
      actualFingerprint: fingerprintText,
    ));
    return false;
  }

  /// Overwrites the stored fingerprint with the current one after the user
  /// explicitly chose to trust a changed host key.
  Future<void> trustChangedKey({
    required String host,
    required int port,
    required String keyType,
    required List<int> fingerprint,
  }) async {
    final hostPort = '$host:$port';
    await _repository.save(KnownHost(
      hostPort: hostPort,
      keyType: keyType,
      fingerprint: utf8.decode(fingerprint),
      firstSeenAt: DateTime.now(),
    ));
  }
}