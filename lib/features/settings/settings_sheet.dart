import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/settings_provider.dart';
import '../../core/utils/terminal_font.dart';
import '../../ui/common/theme.dart';

/// Bottom sheet shown from the terminal ("终端设置") to adjust font family and
/// font size on the fly.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('终端设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('字体'),
            Wrap(
              spacing: 8,
              children: [
                for (final font in TerminalFont.values)
                  ChoiceChip(
                    label: Text(font.label),
                    selected: settings.fontFamily == font,
                    onSelected: (_) => notifier.setFontFamily(font),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('字号'),
            Row(
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  onPressed: settings.fontSize <= TerminalFontDefaults.minSize
                      ? null
                      : () => notifier.setFontSize(settings.fontSize - 1),
                ),
                Expanded(
                  child: Slider(
                    value: settings.fontSize,
                    min: TerminalFontDefaults.minSize,
                    max: TerminalFontDefaults.maxSize,
                    divisions: 12,
                    label: settings.fontSize.roundToDouble().toString(),
                    onChanged: (v) => notifier.setFontSize(v.roundToDouble()),
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  onPressed: settings.fontSize >= TerminalFontDefaults.maxSize
                      ? null
                      : () => notifier.setFontSize(settings.fontSize + 1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '当前：${settings.fontFamily.label} · ${settings.fontSize.round()}pt',
              style: const TextStyle(color: AppColors.blue30),
            ),
          ],
        ),
      ),
    );
  }
}