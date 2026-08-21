import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/port_forward_rule.dart';

/// Editable list of port-forwarding rules for the Add/Edit server screen,
/// mirroring the original `PortForwardSection`.
class PortForwardSection extends StatefulWidget {
  const PortForwardSection({
    super.key,
    required this.rules,
    required this.onChanged,
  });

  final List<PortForwardRule> rules;
  final ValueChanged<List<PortForwardRule>> onChanged;

  @override
  State<PortForwardSection> createState() => _PortForwardSectionState();
}

class _PortForwardSectionState extends State<PortForwardSection> {
  static const _empty = PortForwardRule(
    type: ForwardType.local,
    enabled: true,
    listenHost: defaultListenHost,
    listenPort: defaultListenPort,
    destHost: defaultDestHost,
    destPort: defaultDestPort,
  );

  void _add() => widget.onChanged([...widget.rules, _empty]);

  void _remove(int index) =>
      widget.onChanged([...widget.rules]..removeAt(index));

  Future<void> _edit(PortForwardRule rule, int index) async {
    final edited = await showDialog<PortForwardRule>(
      context: context,
      builder: (_) => _RuleEditor(rule: rule),
    );
    if (edited != null) {
      final copy = [...widget.rules];
      copy[index] = edited;
      widget.onChanged(copy);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('端口转发',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('添加规则'),
            ),
          ],
        ),
        if (widget.rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('暂无规则',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
        for (var i = 0; i < widget.rules.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Switch(
                value: widget.rules[i].enabled,
                onChanged: (v) {
                  final copy = [...widget.rules];
                  copy[i] = widget.rules[i].copyWith(enabled: v);
                  widget.onChanged(copy);
                },
              ),
              title: Text(widget.rules[i].label),
              subtitle: Text(widget.rules[i].enabled ? '已启用' : '已禁用'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(widget.rules[i], i),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(i),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({required this.rule});

  final PortForwardRule rule;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late ForwardType _type = widget.rule.type;
  late final TextEditingController _listenHost =
      TextEditingController(text: widget.rule.listenHost);
  late final TextEditingController _listenPort =
      TextEditingController(text: widget.rule.listenPort.toString());
  late final TextEditingController _destHost =
      TextEditingController(text: widget.rule.destHost);
  late final TextEditingController _destPort =
      TextEditingController(text: widget.rule.destPort.toString());

  @override
  void dispose() {
    _listenHost.dispose();
    _listenPort.dispose();
    _destHost.dispose();
    _destPort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑转发规则'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<ForwardType>(
              segments: const [
                ButtonSegment(value: ForwardType.local, label: Text('本地')),
                ButtonSegment(value: ForwardType.remote, label: Text('远程')),
                ButtonSegment(value: ForwardType.dynamic, label: Text('动态')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _listenHost,
              enabled: _type != ForwardType.remote,
              decoration: const InputDecoration(labelText: '监听地址'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _listenPort,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '监听端口'),
            ),
            const SizedBox(height: 8),
            if (_type != ForwardType.dynamic) ...[
              TextField(
                controller: _destHost,
                decoration: const InputDecoration(labelText: '目标地址'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _destPort,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '目标端口'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(PortForwardRule(
              type: _type,
              enabled: widget.rule.enabled,
              listenHost: _type == ForwardType.remote
                  ? widget.rule.listenHost
                  : (_listenHost.text.isEmpty ? defaultListenHost : _listenHost.text),
              listenPort: int.tryParse(_listenPort.text) ?? defaultListenPort,
              destHost: _destHost.text.isEmpty ? defaultDestHost : _destHost.text,
              destPort: int.tryParse(_destPort.text) ?? defaultDestPort,
            ));
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}