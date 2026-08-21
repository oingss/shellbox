import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/port_forward_rule.dart';
import '../../core/models/server.dart';
import '../../core/models/server_common.dart';
import '../../core/state/home_provider.dart';
import '../../core/state/providers.dart';
import 'port_forward_section.dart';

/// Add / edit a saved server, including its port-forwarding rules.
class AddServerScreen extends ConsumerStatefulWidget {
  const AddServerScreen({super.key, this.existing});

  /// When provided the form pre-fills and saving updates instead of inserting.
  final Server? existing;

  @override
  ConsumerState<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends ConsumerState<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _keyText;
  late final TextEditingController _passphrase;
  String? _keyFilePath;

  late AuthType _authType;
  late PrivateKeySource _keySource;
  late List<PortForwardRule> _rules;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _name = TextEditingController(text: s?.name ?? '');
    _host = TextEditingController(text: s?.host ?? '');
    _port = TextEditingController(text: (s?.port ?? 22).toString());
    _username = TextEditingController(text: s?.username ?? '');
    _password = TextEditingController(text: s?.password ?? '');
    _keyText = TextEditingController(
        text: s != null && s.privateKeySource == PrivateKeySource.text
            ? s.privateKeyValue ?? ''
            : '');
    _passphrase = TextEditingController(text: s?.privateKeyPassphrase ?? '');
    _keyFilePath =
        s != null && s.privateKeySource == PrivateKeySource.file
            ? s.privateKeyValue
            : null;
    _authType = s?.authType ?? AuthType.password;
    _keySource = s?.privateKeySource ?? PrivateKeySource.text;
    _rules = s?.portForwardRules.toList() ?? [];
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _keyText.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _pickKeyFile() async {
    final picker = ref.read(appServicesProvider).filePicker.pickKeyFile();
    final path = await picker;
    if (path != null) {
      setState(() {
        _keySource = PrivateKeySource.file;
        _keyFilePath = path;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);

    final now = widget.existing?.createdAt ?? DateTime.now();
    final server = Server(
      id: widget.existing?.id,
      name: _name.text.trim(),
      host: _host.text.trim(),
      port: int.tryParse(_port.text) ?? 22,
      username: _username.text.trim(),
      authType: _authType,
      password: _authType == AuthType.password ? _password.text : null,
      privateKeySource: _authType == AuthType.privateKey ? _keySource : null,
      privateKeyValue: _authType == AuthType.privateKey
          ? (_keySource == PrivateKeySource.file
              ? _keyFilePath
              : _keyText.text.trim())
          : null,
      privateKeyPassphrase: _authType == AuthType.privateKey &&
              _keySource == PrivateKeySource.text
          ? _passphrase.text
          : null,
      createdAt: now,
      lastUsedAt: widget.existing?.lastUsedAt,
      portForwardRules: _rules,
    );

    await ref.read(homeProvider.notifier).saveOrUpdate(server);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? '添加服务器' : '编辑服务器')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '名称'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _host,
              decoration: const InputDecoration(labelText: '主机'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入主机' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _port,
              decoration: const InputDecoration(labelText: '端口'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final value = int.tryParse(v ?? '');
                if (value == null || value < 1 || value > 65535) {
                  return '端口 1-65535';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: '用户名'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入用户名' : null,
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('认证方式'),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AuthType>(
              segments: const [
                ButtonSegment(value: AuthType.password, label: Text('密码')),
                ButtonSegment(value: AuthType.privateKey, label: Text('私钥')),
              ],
              selected: {_authType},
              onSelectionChanged: (s) => setState(() => _authType = s.first),
            ),
            const SizedBox(height: 16),
            if (_authType == AuthType.password)
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码'),
              )
            else ...[
              SegmentedButton<PrivateKeySource>(
                segments: const [
                  ButtonSegment(
                      value: PrivateKeySource.text, label: Text('粘贴内容')),
                  ButtonSegment(
                      value: PrivateKeySource.file, label: Text('选择文件')),
                ],
                selected: {_keySource},
                onSelectionChanged: (s) =>
                    setState(() => _keySource = s.first),
              ),
              const SizedBox(height: 12),
              if (_keySource == PrivateKeySource.text)
                TextFormField(
                  controller: _keyText,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '私钥内容 (PEM / OpenSSH)',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入私钥' : null,
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.key),
                  title: Text(_keyFilePath == null
                      ? '未选择私钥文件'
                      : _keyFilePath!.split(RegExp(r'[\\/]')).last),
                  trailing: OutlinedButton(
                    onPressed: _pickKeyFile,
                    child: const Text('选择文件'),
                  ),
                ),
              const SizedBox(height: 8),
              if (_keySource == PrivateKeySource.text)
                TextFormField(
                  controller: _passphrase,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '私钥密码 (可选)'),
                ),
            ],
            const SizedBox(height: 24),
            PortForwardSection(
              rules: _rules,
              onChanged: (rules) => setState(() => _rules = rules),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}