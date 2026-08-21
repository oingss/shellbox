import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/quick_connect.dart';
import '../../core/models/server.dart';
import '../../core/models/server_common.dart';
import '../../core/state/providers.dart';
import '../terminal/terminal_screen.dart';

/// 快速连接 dialog: a one-off SSH connection that is not persisted.
class QuickConnectDialog extends ConsumerStatefulWidget {
  const QuickConnectDialog({super.key});

  @override
  ConsumerState<QuickConnectDialog> createState() => _QuickConnectDialogState();
}

class _QuickConnectDialogState extends ConsumerState<QuickConnectDialog> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _testing = false;
  String? _testResult;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final server = _server();
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final manager = await ref.read(sshManagerProvider.future);
    final message = await manager.testConnection(server);
    if (!mounted) {
      return;
    }
    setState(() {
      _testing = false;
      _testResult = message ?? '连接成功';
    });
  }

  void _connect() {
    final server = _server();
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TerminalScreen(servers: [server]),
    ));
  }

  Server _server() {
    return QuickConnect(
      host: _host.text.trim(),
      port: int.tryParse(_port.text) ?? 22,
      username: _username.text.trim(),
      authType: AuthType.password,
      password: _password.text,
    ).toServer();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('快速连接'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _host,
              decoration: const InputDecoration(labelText: '主机'),
              keyboardType: TextInputType.url,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _port,
                    decoration: const InputDecoration(labelText: '端口'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: '用户名'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            if (_testResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testResult == '连接成功'
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _testing ? null : _test,
          child: _testing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('测试连接'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _connect,
          icon: const Icon(Icons.call_merge),
          label: const Text('连接'),
        ),
      ],
    );
  }
}