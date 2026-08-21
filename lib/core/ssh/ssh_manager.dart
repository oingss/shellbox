import 'package:dartssh2/dartssh2.dart';

import '../models/server.dart';
import 'key_loader.dart';
import 'known_hosts_verifier.dart';

/// Result of an SSH connection attempt.
sealed class SshResult {
  const SshResult();
}

/// Established an interactive shell belonging to [SshSession].
final class SshConnected extends SshResult {
  const SshConnected(this.session);
  final SshSession session;
}

/// Connection / authentication failed.
final class SshFailed extends SshResult {
  const SshFailed(this.message);
  final String message;
}

/// Host key changed between visits; the UI should confirm trust via
/// [SshManager.trustChangedKey] then retry.
final class SshHostKeyChanged extends SshResult {
  const SshHostKeyChanged({
    required this.storedFingerprint,
    required this.actualFingerprint,
  });
  final String storedFingerprint;
  final String actualFingerprint;
}

/// A live SSH shell session.
class SshSession {
  const SshSession({
    required this.id,
    required this.label,
    required this.client,
    required this.shell,
  });

  final String id;
  final String label;
  final SSHClient client;

  /// The established shell channel (PTY).
  final SSHSession shell;

  Future<void> close() async {
    try {
      shell.close();
    } catch (_) {}
    try {
      await client.close();
    } catch (_) {}
  }
}

/// Owns every live SSH connection. The original app mirrored this as a
/// singleton [SshManager].
class SshManager {
  SshManager(this._keyLoader, this._hostVerifier);

  final KeyLoader _keyLoader;
  final KnownHostsVerifier _hostVerifier;

  static const _keepAliveInterval = Duration(seconds: 15);

  final Map<String, SshSession> _sessions = {};

  List<SshSession> get sessions => List.unmodifiable(_sessions.values);
  int get activeCount => _sessions.length;
  SshSession? byId(String id) => _sessions[id];

  void register(SshSession session) => _sessions[session.id] = session;

  void unregister(String id) => _sessions.remove(id);

  /// Connects, authenticates, and opens an interactive shell.
  Future<SshResult> connect(Server server) async {
    // TOFU host-key outcome from the current handshake, so the caller can
    // differentiate a changed key from other failures.
    VerifyOutcome? lastOutcome;

    final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(server.host, server.port);
    } catch (error) {
      return SshFailed(_friendlyAuthError(server.host, error));
    }

    final SSHClient client = SSHClient(
      socket,
      username: server.username,
      keepAliveInterval: _keepAliveInterval,
      handshakeTimeout: const Duration(seconds: 15),
      authTimeout: const Duration(seconds: 15),
      onPasswordRequest: () => server.password,
      identities: await _keyLoader.loadFor(server),
      onVerifyHostKey: (type, fingerprint) =>
          _hostVerifier.handleHostKey(
        host: server.host,
        port: server.port,
        keyType: type,
        fingerprint: fingerprint,
        onOutcome: (o) => lastOutcome = o,
      ),
    );

    try {
      await client.authenticated;
    } catch (error) {
      try { await client.close(); } catch (_) {}
      if (lastOutcome
          case Mismatch(
            :final storedFingerprint,
            :final actualFingerprint,
          )) {
        return SshHostKeyChanged(
          storedFingerprint: storedFingerprint,
          actualFingerprint: actualFingerprint,
        );
      }
      return SshFailed(_friendlyAuthError(server.host, error));
    }

    final shell = await _createSession(client);
    if (shell == null) {
      try { await client.close(); } catch (_) {}
      return const SshFailed('无法打开交互终端');
    }
    final session = SshSession(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_sessions.length}',
      label: server.name,
      client: client,
      shell: shell,
    );
    register(session);
    return SshConnected(session);
  }

  Future<SSHSession?> _createSession(SSHClient client) async {
    try {
      return await client.shell(
        pty: const SSHPtyConfig(
          type: 'xterm-256color',
          width: 80,
          height: 25,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// After [SshHostKeyChanged], records the new key and retries.
  Future<SshResult> retryWithNewTrust(Server server,
      {required String keyType, required List<int> fingerprint}) async {
    await _hostVerifier.trustChangedKey(
      host: server.host,
      port: server.port,
      keyType: keyType,
      fingerprint: fingerprint,
    );
    return connect(server);
  }

  /// Quick connectivity probe: connects, then tears the session down. Returns
  /// null on success, otherwise the error message.
  Future<String?> testConnection(Server server) async {
    final result = await connect(server);
    switch (result) {
      case SshConnected(:final session):
        unregister(session.id);
        await session.close();
        return null;
      case SshHostKeyChanged(:final actualFingerprint):
        return '主机密钥已变化：$actualFingerprint';
      case SshFailed(:final message):
        return message;
    }
  }

  Future<void> closeAll() async {
    final pending = _sessions.values.map((s) => s.close());
    _sessions.clear();
    await Future.wait(pending);
  }

  String _friendlyAuthError(String host, Object error) {
    final text = error.toString();
    if (text.contains('PasswordAuth') || text.contains('publickey')) {
      return '认证失败：请检查用户名、密码或私钥';
    }
    if (text.contains('Timeout') || text.contains('connect')) {
      return '连接超时：无法访问 $host';
    }
    return text;
  }
}