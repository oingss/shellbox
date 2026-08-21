import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../models/port_forward_rule.dart';

/// Result of starting one forward rule.
sealed class PortForwardStartResult {
  const PortForwardStartResult();
}

final class ForwardStarted extends PortForwardStartResult {
  const ForwardStarted(this.rule);
  final PortForwardRule rule;
}

final class ForwardFailed extends PortForwardStartResult {
  const ForwardFailed(this.rule, this.message);
  final PortForwardRule rule;
  final String message;
}

/// Starts/stops the three kinds of port forwarding on a live [SSHClient],
/// matching the original sshj `PortForwardManager`.
class PortForwardManager {
  PortForwardManager(this._client);

  final SSHClient _client;

  final Map<String, Future<void> Function()> _stopped = {};
  final Map<String, StreamSubscription<dynamic>> _subs = {};
  final Set<String> _started = {};

  bool isRunning(String ruleId) => _started.contains(ruleId);

  Future<PortForwardStartResult> start(PortForwardRule rule) async {
    final key = rule.effectiveId(const {});
    if (_started.contains(key)) {
      return ForwardStarted(rule);
    }

    try {
      switch (rule.type) {
        case ForwardType.local:
          await _startLocal(rule, key);
        case ForwardType.remote:
          await _startRemote(rule, key);
        case ForwardType.dynamic:
          await _startDynamic(rule, key);
      }
      _started.add(key);
      return ForwardStarted(rule);
    } catch (e) {
      return ForwardFailed(rule, e.toString());
    }
  }

  Future<void> _startLocal(PortForwardRule rule, String key) async {
    // Bind locally; each inbound connection gets its own remote forward.
    final server = await ServerSocket.bind(rule.listenHost, rule.listenPort);
    _stopped[key] = () async {
      await server.close();
    };

    server.listen((socket) async {
      try {
        final fwd = await _client.forwardLocal(rule.destHost, rule.destPort);
        final sub = fwd.stream.cast<List<int>>().listen(socket.add,
            onError: (_) => socket.destroy());
        socket.listen((data) => fwd.sink.add(data), onDone: () {
          sub.cancel();
          fwd.sink.close();
        });
      } catch (_) {
        socket.destroy();
      }
    });
  }

  Future<void> _startRemote(PortForwardRule rule, String key) async {
    final forwarder = await _client.forwardRemote(
      host: rule.listenHost == defaultListenHost ? null : rule.listenHost,
      port: rule.listenPort,
    );
    if (forwarder == null) {
      throw const SocketException('远程端口转发被拒绝');
    }

    final sub = forwarder.connections.listen((connection) async {
      try {
        final socket = await Socket.connect(rule.destHost, rule.destPort);
        connection.stream.cast<List<int>>().listen(socket.add,
            onError: (_) => socket.destroy());
        socket.listen((data) => connection.sink.add(data), onDone: () {
          connection.sink.close();
        });
      } catch (_) {
        connection.sink.close();
      }
    });
    _subs[key] = sub;
    // The port lives on the server side; release it explicitly on stop.
    _stopped[key] = () async {
      await sub.cancel();
      forwarder.close();
    };
  }

  Future<void> _startDynamic(PortForwardRule rule, String key) async {
    await _client.forwardDynamic(
      bindHost: rule.listenHost,
      bindPort: rule.listenPort,
    );
    // The SOCKS listener is torn down together with the SSH client.
    _stopped[key] = () async {};
  }

  Future<void> stop(String ruleId) async {
    final stop = _stopped.remove(ruleId);
    if (stop == null) {
      return;
    }
    _started.remove(ruleId);
    try {
      await stop();
    } catch (_) {}
  }

  Future<void> stopAll() async {
    final stops = _stopped.values.map((stop) => stop());
    _stopped.clear();
    _started.clear();
    _subs.clear();
    await Future.wait(stops);
  }
}