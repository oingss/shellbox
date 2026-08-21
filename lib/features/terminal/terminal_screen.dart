import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../core/models/server.dart';
import '../../core/ssh/ssh_manager.dart';
import '../../core/ssh/terminal_bridge.dart';
import '../../core/state/settings_provider.dart';
import '../../core/state/terminal_provider.dart';
import '../../core/utils/vkey_config.dart';
import '../../ui/common/theme.dart';
import '../settings/settings_sheet.dart';

/// One tab rendering one xterm view bound to a live SSH session.
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key, required this.servers});

  /// Servers to open on startup / retry. Only the first is attempted per app
  /// launch of this screen; the rest are offered as reconnect targets.
  final List<Server> servers;

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final Map<String, Terminal> _terminals = {};
  final Map<String, TerminalController> _controllers = {};
  final Map<String, TerminalBridge> _bridges = {};
  final FocusNode _keyFocus = FocusNode();
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _openFirst();
  }

  Future<void> _openFirst() async {
    final server = widget.servers.firstOrNull;
    if (server == null) {
      return;
    }
    await _connectNew(server);
  }

  Future<bool> _connectNew(Server server) async {
    try {
      final tab = await ref.read(terminalTabsProvider.notifier).openTab(server);

      final terminal = Terminal(
        maxLines: 1000,
        onBell: () {},
      );
      final controller = TerminalController();
      final bridge = TerminalBridge(terminal, tab.session.shell)
        ..onTitleChange = (t) {
          if (mounted) {
            setState(() {});
          }
        };

      _terminals[tab.id] = terminal;
      _controllers[tab.id] = controller;
      _bridges[tab.id] = bridge;

      setState(() => _activeId = tab.id);
      return true;
    } on SshHostKeyChanged catch (e) {
      _showSnackBar('主机密钥已变化，请先在设置中删除该主机记录后重试 '
          '(${e.actualFingerprint})');
      return false;
    } on SshFailed catch (e) {
      _showSnackBar(e.message);
      return false;
    }
  }

  void _closeTab(String id) {
    if (id == _activeId) {
      final idx = ref.read(terminalTabsProvider).indexWhere((t) => t.id == id);
      final next = ref.read(terminalTabsProvider).elementAtOrNull(idx + 1);
      _activeId = next?.id ?? (idx > 0
              ? ref.read(terminalTabsProvider).elementAtOrNull(idx - 1)?.id
              : null);
    }
    _terminals.remove(id);
    _controllers.remove(id);
    _bridges.remove(id)?.dispose();
    ref.read(terminalTabsProvider.notifier).closeTab(id);

    if (_activeId == null && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _sendRaw(String id, String data) {
    _bridges[id]?.writeLocal(data);
  }

  final Map<String, bool> _latchCtrl = {};
  final Map<String, bool> _latchAlt = {};
  final Map<String, bool> _latchShift = {};

  bool _isLatched(String id, VKeyAction a) {
    if (a == VKeyAction.toggleCtrl) {
      return _latchCtrl[id] ?? false;
    }
    if (a == VKeyAction.toggleAlt) {
      return _latchAlt[id] ?? false;
    }
    if (a == VKeyAction.toggleShift) {
      return _latchShift[id] ?? false;
    }
    return false;
  }

  void _toggleLatch(String id, VKeyAction action) {
    setState(() {
      final target = switch (action) {
        VKeyAction.toggleCtrl => _latchCtrl,
        VKeyAction.toggleAlt => _latchAlt,
        VKeyAction.toggleShift => _latchShift,
        _ => null,
      };
      target?[id] = !(target[id] ?? false);
    });
  }

  void _handleVKey(String id, VKeyAction action) {
    switch (action) {
      case VKeyAction.arrowUp:
        _sendModified(id, _isLatched(id, VKeyAction.toggleCtrl) ? '[1;5A' : '[A');
      case VKeyAction.arrowDown:
        _sendModified(id, _isLatched(id, VKeyAction.toggleCtrl) ? '[1;5B' : '[B');
      case VKeyAction.arrowRight:
        _sendModified(id, _isLatched(id, VKeyAction.toggleCtrl) ? '[1;5C' : '[C');
      case VKeyAction.arrowLeft:
        _sendModified(id, _isLatched(id, VKeyAction.toggleCtrl) ? '[1;5D' : '[D');
      case VKeyAction.pageUp:
        _sendRaw(id, '\u001b[5~');
      case VKeyAction.pageDown:
        _sendRaw(id, '\u001b[6~');
      case VKeyAction.home:
        _sendRaw(id, '\u001b[H');
      case VKeyAction.end:
        _sendRaw(id, '\u001b[F');
      case VKeyAction.esc:
        _sendRaw(id, '\u001b');
      case VKeyAction.tab:
        _sendRaw(id, '\t');
      case VKeyAction.enter:
        _sendRaw(id, '\r');
      case VKeyAction.backspace:
        _sendRaw(id, '\u007f');
      case VKeyAction.toggleCtrl:
      case VKeyAction.toggleAlt:
      case VKeyAction.toggleShift:
        _toggleLatch(id, action);
      case VKeyAction.showKeyboard:
        _keyFocus.requestFocus();
      case VKeyAction.sendText:
        _promptSendText(id);
    }
  }

  /// Sends `\x1b` + [seq]; an Alt latch could prepend a second ESC to build
  /// the `\x1b\x1b[...` sequence used by some line editors.
  void _sendModified(String id, String seq) {
    _sendRaw(id, '\u001b$seq');
  }

  void _promptSendText(String id) {
    final controller = TextEditingController();
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发送文本'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入要发送的文本'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('发送'),
          ),
        ],
      ),
    ).then((text) {
      if (text != null) {
        _sendRaw(id, text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(terminalTabsProvider);
    final active = _activeId == null
        ? null
        : tabs.where((t) => t.id == _activeId).firstOrNull;

    return Scaffold(
      backgroundColor: _terminalBackground(),
      body: Column(
        children: [
          _buildTabBar(tabs, active),
          Expanded(
            child: active == null
                ? const Center(child: Text('没有活动连接'))
                : _buildTerminalView(active.id),
          ),
          if (MediaQuery.of(context).size.shortestSide < 600)
            _buildVirtualKeyboard(active?.id),
        ],
      ),
    );
  }

  Column _buildTabBar(List<TerminalTab> tabs, TerminalTab? active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 48,
          color: AppColors.blue95,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final t in tabs)
                      GestureDetector(
                        onTap: () => setState(() => _activeId = t.id),
                        child: Container(
                          alignment: Alignment.center,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: active?.id == t.id
                                ? AppColors.blue40
                                : AppColors.blue90,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.label,
                                style: TextStyle(
                                  color: active?.id == t.id
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _closeTab(t.id),
                                child: Icon(Icons.close,
                                    size: 16,
                                    color: active?.id == t.id
                                        ? Colors.white70
                                        : Colors.black45),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () async {
                  final relyingServer = widget.servers.firstOrNull;
                  if (relyingServer != null) {
                    await _connectNew(relyingServer);
                  }
                },
                tooltip: '新建连接',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTerminalView(String tabId) {
    final terminal = _terminals[tabId];
    final controller = _controllers[tabId];
    if (terminal == null || controller == null) {
      return const SizedBox.shrink();
    }
    final settings = ref.watch(settingsProvider);

    return TerminalView(
      terminal,
      controller: controller,
      focusNode: _keyFocus,
      autofocus: true,
      autoResize: true,
      theme: TerminalThemes.defaultTheme,
      backgroundOpacity: 0,
      textStyle: TerminalStyle(
        fontFamily:
            settings.fontFamily.family ?? defaultFontFamily(),
        fontSize: settings.fontSize,
      ),
      onTapUp: (details, keys) {},
      onSecondaryTapDown: (details, keys) {
        _showContextMenu(tabId, details.globalPosition);
      },
    );
  }

  String defaultFontFamily() {
    return 'Menlo, Consolas, monospace';
  }

  Color _terminalBackground() => const Color(0xFFF7F9FF);

  void _showContextMenu(String tabId, Offset position) {
    showMenu<String>(
      context: context,
      position:
          RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: const [
        PopupMenuItem(value: 'copy', child: Text('复制选中内容')),
        PopupMenuItem(value: 'settings', child: Text('终端设置')),
      ],
    ).then((value) {
      if (!mounted) {
        return;
      }
      switch (value) {
        case 'copy':
          final sel = _selectedText(tabId);
          if (sel.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: sel));
            _showSnackBar('已复制');
          } else {
            _showSnackBar('没有选中内容');
          }
          break;
        case 'settings':
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const SettingsSheet(),
          );
          break;
      }
    });
  }

  /// Extracts the selected cells via the controller's [BufferRange] segments.
  /// Returns '' when there is no selection.
  String _selectedText(String tabId) {
    final terminal = _terminals[tabId];
    final controller = _controllers[tabId];
    if (terminal == null || controller == null) {
      return '';
    }
    final sel = controller.selection;
    if (sel == null) {
      return '';
    }
    final lines = terminal.buffer.lines;
    final sb = StringBuffer();
    final segments = sel.toSegments().toList();
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.line >= lines.length) {
        continue;
      }
      final line = lines[seg.line];
      final from = seg.start ?? 0;
      final to = seg.end;
      sb.write(to == null ? line.getText(from) : line.getText(from, to));
      if (i != segments.length - 1 && !line.isWrapped) {
        sb.write('\n');
      }
    }
    return sb.toString();
  }

  Widget _buildVirtualKeyboard(String? tabId) {
    if (tabId == null) {
      return const SizedBox.shrink();
    }
    final rows = VKeyLayoutStore.fromStoredJson(null);
    return Container(
      height: 130,
      color: Colors.white,
      child: Column(
        children: [
          for (final row in rows)
            Row(
              children: [
                for (final action in row.actions)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Material(
                        color: _latchColor(tabId, action),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _handleVKey(tabId, action),
                          child: Center(
                            child: Text(
                              action.icon,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Color _latchColor(String tabId, VKeyAction action) {
    if (_isLatched(tabId, action)) {
      return AppColors.blue90;
    }
    return Colors.grey.shade200;
  }

  @override
  void dispose() {
    for (final bridge in _bridges.values) {
      bridge.dispose();
    }
    _keyFocus.dispose();
    super.dispose();
  }
}