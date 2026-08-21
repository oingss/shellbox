import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/server.dart';
import '../ssh/port_forward_manager.dart';
import '../ssh/ssh_manager.dart';
import 'providers.dart';

/// One open terminal tab bound to a live [SSHManager] session.
class TerminalTab {
  TerminalTab({
    required this.id,
    required this.label,
    required this.session,
    required this.forwards,
  });

  final String id;
  final String label;
  final SshSession session;
  final PortForwardManager forwards;

  Future<void> dispose() async {
    await forwards.stopAll();
    await session.close();
  }
}

/// Registry of open terminal tabs; mirrors the original TerminalState.
class TerminalNotifier extends Notifier<List<TerminalTab>> {
  @override
  List<TerminalTab> build() {
    ref.onDispose(() {
      Future(() => ref.read(sshManagerProvider.future).then((m) => m.closeAll()));
    });
    return const [];
  }

  /// Opens a new shell for [server], wiring port forwards and returning the
  /// tab. Throws SshFailed/SshHostKeyChanged on connection error.
  Future<TerminalTab> openTab(Server server) async {
    final manager = await ref.read(sshManagerProvider.future);
    final result = await manager.connect(server);

    switch (result) {
      case SshConnected(:final session):
        final forwards = PortForwardManager(session.client);
        for (final rule in server.portForwardRules.where((r) => r.enabled)) {
          await forwards.start(rule);
        }
        final tab = TerminalTab(
          id: session.id,
          label: server.name,
          session: session,
          forwards: forwards,
        );
        state = [...state, tab];

        final settings = ref.read(terminalSettingsProvider);
        if (settings.keepAliveEnabled) {
          await ref.read(appServicesProvider).keepAlive.start();
        }
        return tab;

      case SshHostKeyChanged():
        throw result;

      case SshFailed():
        throw result;
    }
  }

  void closeTab(String id) async {
    final tab = state.where((t) => t.id == id).firstOrNull;
    if (tab != null) {
      await tab.dispose();
    }
    state = state.where((t) => t.id != id).toList();
    await ref.read(sshManagerProvider.future).then((m) {
      m.unregister(id);
      final alive = state.where((t) => t.id != id);
      if (alive.isEmpty) {
        ref.read(appServicesProvider).keepAlive.stop();
      }
    });
  }
}

final terminalTabsProvider =
    NotifierProvider<TerminalNotifier, List<TerminalTab>>(TerminalNotifier.new);