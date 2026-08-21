import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/server.dart';
import '../../core/state/home_provider.dart';
import '../../core/state/providers.dart';
import '../../ui/common/theme.dart';
import '../add_server/add_server_screen.dart';
import '../sftp/sftp_screen.dart';
import '../terminal/terminal_screen.dart';
import 'quick_connect_dialog.dart';
import 'server_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _testing = false;

  void _openServer(Server server) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TerminalScreen(servers: [server]),
    ));
  }

  void _edit(Server server) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddServerScreen(existing: server),
    ));
  }

  Future<void> _delete(Server server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定删除「${server.name}」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && server.id != null) {
      await ref.read(homeProvider.notifier).delete(server.id!);
    }
  }

  Future<void> _test(Server server) async {
    setState(() => _testing = true);
    final manager = await ref.read(sshManagerProvider.future);
    final message = await manager.testConnection(server);
    setState(() => _testing = false);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message ?? '连接成功'),
      backgroundColor: message == null ? Colors.green.shade700 : null,
    ));
  }

  void _showQuickConnect() {
    showDialog<void>(
      context: context,
      builder: (_) => const QuickConnectDialog(),
    );
  }

  void _openAddServer() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const AddServerScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(homeProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShellBox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: '快速连接',
            onPressed: _showQuickConnect,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add',
        onPressed: _openAddServer,
        icon: const Icon(Icons.add),
        label: const Text('添加服务器'),
      ),
      body: servers.when(
        data: (list) => list.isEmpty
            ? _emptyState()
            : isDesktop
                ? _grid(list)
                : _list(list),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_outlined, size: 64, color: AppColors.blue40),
          const SizedBox(height: 12),
          const Text('还没有服务器，先添加一台吧'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openAddServer,
            icon: const Icon(Icons.add),
            label: const Text('添加服务器'),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<Server> servers) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: servers.length,
      itemBuilder: (context, i) => ServerCard(
        server: servers[i],
        testing: _testing,
        onTap: () => _openServer(servers[i]),
        onLongPress: () => _serverMenu(servers[i]),
      ),
    );
  }

  Widget _list(List<Server> servers) {
    return ListView.separated(
      itemCount: servers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => ServerCard(
        server: servers[i],
        testing: _testing,
        compact: true,
        onTap: () => _openServer(servers[i]),
        onLongPress: () => _serverMenu(servers[i]),
      ),
    );
  }

  void _serverMenu(Server server) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text('连接'),
              onTap: () {
                Navigator.of(ctx).pop();
                _openServer(server);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () {
                Navigator.of(ctx).pop();
                _edit(server);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('打开 SFTP'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SftpScreen(server: server),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('测试连接'),
              onTap: () {
                Navigator.of(ctx).pop();
                _test(server);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () {
                Navigator.of(ctx).pop();
                _delete(server);
              },
            ),
          ],
        ),
      ),
    );
  }
}