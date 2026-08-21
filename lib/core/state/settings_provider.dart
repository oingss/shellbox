import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/terminal_font.dart';
import 'providers.dart';

final class SettingsState {
  SettingsState({
    required this.fontSize,
    required this.fontFamily,
    required this.keepAliveEnabled,
  });

  final double fontSize;
  final TerminalFont fontFamily;
  final bool keepAliveEnabled;
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final store = ref.watch(terminalSettingsProvider);
    return SettingsState(
      fontSize: store.fontSize,
      fontFamily: store.fontFamily,
      keepAliveEnabled: store.keepAliveEnabled,
    );
  }

  Future<void> setFontSize(double size) async {
    await ref.read(terminalSettingsProvider).setFontSize(size);
    state = SettingsState(
      fontSize: size,
      fontFamily: state.fontFamily,
      keepAliveEnabled: state.keepAliveEnabled,
    );
  }

  Future<void> setFontFamily(TerminalFont font) async {
    await ref.read(terminalSettingsProvider).setFontFamily(font);
    state = SettingsState(
      fontSize: state.fontSize,
      fontFamily: font,
      keepAliveEnabled: state.keepAliveEnabled,
    );
  }

  Future<void> setKeepAliveEnabled(bool value) async {
    await ref.read(terminalSettingsProvider).setKeepAliveEnabled(value);
    state = SettingsState(
      fontSize: state.fontSize,
      fontFamily: state.fontFamily,
      keepAliveEnabled: value,
    );
    if (!value) {
      await ref.read(appServicesProvider).keepAlive.stop();
    }
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);