import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sftp_file_entry.dart';
import '../models/server.dart';
import '../ssh/sftp_repository.dart';
import '../ssh/ssh_manager.dart';
import 'providers.dart';

/// Current SFTP connection: owns the SftpRepository (plus the shared SSH
/// client) so multiple screens can reuse one connection, matching the original
/// SFTP screen that reused a live SSH session.
class SftpConnection {
  SftpConnection(this.label, this.sshSession, this.repo);
  final String label;
  final SshSession sshSession;
  final SftpRepository repo;

  Future<void> close() async {
    await repo.close();
    await sshSession.close();
  }
}

sealed class SftpState {
  const SftpState();
}

final class SftpIdle extends SftpState {
  const SftpIdle();
}

final class SftpBusy extends SftpState {
  const SftpBusy(this.message);
  final String message;
}

final class SftpReady extends SftpState {
  const SftpReady(this.connection, this.currentPath, this.entries);
  final SftpConnection connection;
  final String currentPath;
  final List<SftpFileEntry> entries;
}

class SftpController extends Notifier<SftpState> {
  @override
  SftpState build() => const SftpIdle();

  /// Establishes the SFTP channel on the given server (fresh SSH session, no
  /// port forwards — SFTP tab reuses its own connection).
  Future<void> connect(Server server) async {
    final manager = await ref.read(sshManagerProvider.future);
    final result = await manager.connect(server);
    switch (result) {
      case SshConnected(:final session):
        final sftp = await session.client.sftp();
        final conn = SftpConnection(
            server.name, session, SftpRepository(sftp));
        state = SftpReady(conn, '/', await _list(conn, '/'));
      case SshFailed(:final message):
        state = SftpBusy(message);
      case SshHostKeyChanged():
        state = SftpBusy('主机密钥已变化，请先返回首页重新连接');
    }
  }

  Future<void> navigate(String path) async {
    final s = state;
    if (s is! SftpReady) {
      return;
    }
    final entries = await _list(s.connection, path);
    state = SftpReady(s.connection, path, entries);
  }

  Future<List<SftpFileEntry>> _list(SftpConnection conn, String path) async {
    final res = await conn.repo.list(path);
    return switch (res) {
      SftpOpSuccess<List<SftpFileEntry>>(:final value) => value,
      SftpOpFailure<List<SftpFileEntry>>() => <SftpFileEntry>[],
    };
  }

  Future<void> disconnect() async {
    final s = state;
    if (s is SftpReady) {
      await s.connection.close();
    }
    state = const SftpIdle();
  }
}

final sftpControllerProvider =
    NotifierProvider<SftpController, SftpState>(SftpController.new);