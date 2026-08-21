import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/state/providers.dart';
import '../../core/state/settings_provider.dart';
import '../../core/utils/terminal_font.dart';
import '../../core/utils/vkey_config.dart';

/// Settings entry screen with the four sub-settings the original app had.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _tile(
            icon: Icons.text_fields,
            title: '字体',
            subtitle:
                '${settings.fontFamily.label} · ${settings.fontSize.round()}pt',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FontSettingsScreen()),
            ),
          ),
          _tile(
            icon: Icons.keyboard,
            title: '虚拟键盘',
            subtitle: '两排按键布局与动作',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KeySettingsScreen()),
            ),
          ),
          _tile(
            icon: Icons.verified_user_outlined,
            title: '已知主机（TOFU）',
            subtitle: '信任过的主机指纹列表',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KnownHostsScreen()),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.power_settings_new),
            title: const Text('后台保活服务'),
            subtitle: const Text('有 SSH 连接时保持前台服务运行'),
            value: settings.keepAliveEnabled,
            onChanged: notifier.setKeepAliveEnabled,
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class FontSettingsScreen extends ConsumerWidget {
  const FontSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('字体')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final font in TerminalFont.values)
            RadioListTile<TerminalFont>(
              title: Text(font.label, style: TextStyle(fontFamily: font.family)),
              value: font,
              groupValue: settings.fontFamily,
              onChanged: (v) {
                if (v != null) {
                  notifier.setFontFamily(v);
                }
              },
            ),
          const SizedBox(height: 16),
          Slider(
            value: settings.fontSize,
            min: TerminalFontDefaults.minSize,
            max: TerminalFontDefaults.maxSize,
            divisions: 12,
            label: settings.fontSize.round().toString(),
            onChanged: (v) => notifier.setFontSize(v.roundToDouble()),
          ),
        ],
      ),
    );
  }
}

class KnownHostsScreen extends ConsumerStatefulWidget {
  const KnownHostsScreen({super.key});

  @override
  ConsumerState<KnownHostsScreen> createState() => _KnownHostsScreenState();
}

class _KnownHostsScreenState extends ConsumerState<KnownHostsScreen> {
  List<_KnownHostRow>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo =
        await ref.read(knownHostRepositoryProvider.future);
    final hosts = await repo.getAll();
    setState(() {
      _rows = hosts
          .map((h) => _KnownHostRow(h.hostPort, h.keyType, h.fingerprint))
          .toList();
    });
  }

  Future<void> _delete(String hostPort) async {
    final repo = await ref.read(knownHostRepositoryProvider.future);
    await repo.delete(hostPort);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('已知主机')),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(child: Text('还没有信任过的主机'))
              : ListView(
                  children: [
                    for (final r in rows)
                      ListTile(
                        title: Text(r.hostPort),
                        subtitle: Text('${r.keyType}\n${r.fingerprint}',
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(r.hostPort),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _KnownHostRow {
  const _KnownHostRow(this.hostPort, this.keyType, this.fingerprint);
  final String hostPort;
  final String keyType;
  final String fingerprint;
}

class KeySettingsScreen extends ConsumerStatefulWidget {
  const KeySettingsScreen({super.key});

  @override
  ConsumerState<KeySettingsScreen> createState() => _KeySettingsScreenState();
}

class _KeySettingsScreenState extends ConsumerState<KeySettingsScreen> {
  List<VKeyRow>? _rows;

  Future<SharedPreferences> _prefs() =>
      ref.read(sharedPreferencesProvider.future);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _prefs();
    setState(() {
      _rows = VKeyLayoutStore.fromStoredJson(
          prefs.getString(VKeyLayoutStore.persistedKey));
    });
  }

  Future<void> _save(List<VKeyRow> rows) async {
    final prefs = await _prefs();
    await prefs.setString(
        VKeyLayoutStore.persistedKey, VKeyLayoutStore.encode(rows));
    setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('虚拟键盘')),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: rows.length,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      for (var i = 0; i < rows.length; i++)
                        Tab(text: '第 ${i + 1} 行'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          ReorderableListView(
                            onReorder: (oldIndex, newIndex) {
                              final list = rows[i].actions.toList();
                              if (newIndex > oldIndex) newIndex--;
                              final item = list.removeAt(oldIndex);
                              list.insert(newIndex, item);
                              rows[i] = VKeyRow(list);
                              _save(rows);
                            },
                            children: [
                              for (final action in rows[i].actions)
                                ListTile(
                                  key: Key(action.name),
                                  leading: const Icon(Icons.drag_handle),
                                  title: Text('${action.icon}  ${action.label}'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}