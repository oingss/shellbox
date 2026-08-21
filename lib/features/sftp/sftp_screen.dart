import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/models/server.dart';
import '../../core/models/sftp_file_entry.dart';
import '../../core/ssh/sftp_repository.dart';
import '../../core/state/sftp_provider.dart';

/// SFTP browser for one server ("文件管理"). Reuses its own SSH session and
/// walks the remote file tree with a breadcrumb path.
class SftpScreen extends ConsumerStatefulWidget {
  const SftpScreen({super.key, required this.server});

  final Server server;

  @override
  ConsumerState<SftpScreen> createState() => _SftpScreenState();
}

class _SftpScreenState extends ConsumerState<SftpScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!_initialized) {
        _initialized = true;
        ref.read(sftpControllerProvider.notifier).connect(widget.server);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sftp = ref.watch(sftpControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('SFTP · ${widget.server.name}')),
      body: switch (sftp) {
        SftpIdle() => const Center(child: CircularProgressIndicator()),
        SftpBusy(:final message) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        SftpReady(:final currentPath, :final entries) => Column(
            children: [
              _breadcrumb(currentPath),
              const Divider(height: 1),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('（空目录）'))
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, i) =>
                            _tile(entries[i], currentPath),
                      ),
              ),
            ],
          ),
      },
    );
  }

  Widget _breadcrumb(String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('/',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          for (var i = 0; i < parts.length; i++) ...[
            const Icon(Icons.chevron_right, size: 18),
            InkWell(
              onTap: () => ref
                  .read(sftpControllerProvider.notifier)
                  .navigate('/${parts.take(i + 1).join('/')}'),
              child: Text(parts[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile(SftpFileEntry entry, String currentPath) {
    final dir = entry.isDirectory;
    return ListTile(
      leading: Icon(dir ? Icons.folder : Icons.insert_drive_file,
          color: dir ? Colors.amber.shade800 : Colors.blueGrey),
      title: Text(entry.name),
      subtitle: Text(
          '${dir ? "--" : entry.displaySize}    ${SftpFileEntry.formatMtime(entry.mtimeSeconds)}'),
      onTap: dir
          ? () => ref
              .read(sftpControllerProvider.notifier)
              .navigate(entry.path)
          : null,
      onLongPress: () => _actions(entry),
    );
  }

  void _actions(SftpFileEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('下载到本地'),
              onTap: () {
                Navigator.of(ctx).pop();
                _download(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () {
                Navigator.of(ctx).pop();
                _delete(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名'),
              onTap: () {
                Navigator.of(ctx).pop();
                _rename(entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(SftpFileEntry entry) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
        SnackBar(content: Text('正在下载 ${entry.name} 到应用私有目录…')));
    // Local dir: app documents (simplified; production would ask a folder).
    final appDir = await appDocumentsDirectory();
    final sftp = ref.read(sftpControllerProvider);
    if (sftp is SftpReady) {
      final res = await sftp.connection.repo.receiveFile(entry, appDir);
      scaffold.showSnackBar(SnackBar(
        content: Text(res is SftpOpFailure ? '下载失败：${res.message}' : '下载完成'),
      ));
    }
  }

  Future<String> appDocumentsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<void> _delete(SftpFileEntry entry) async {
    final sftp = ref.read(sftpControllerProvider);
    if (sftp is! SftpReady) {
      return;
    }
    await sftp.connection.repo.deletePath(entry.path, dir: entry.isDirectory);
    await ref
        .read(sftpControllerProvider.notifier)
        .navigate(sftp.currentPath);
  }

  Future<void> _rename(SftpFileEntry entry) async {
    final controller = TextEditingController(text: entry.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == entry.name) {
      return;
    }
    final parent = entry.path.substring(0, entry.path.lastIndexOf('/') + 1);
    final sftp = ref.read(sftpControllerProvider);
    if (sftp is! SftpReady) {
      return;
    }
    await sftp.connection.repo.rename(entry.path, '$parent$newName');
    await ref.read(sftpControllerProvider.notifier).navigate(sftp.currentPath);
  }
}