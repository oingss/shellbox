import 'package:shared_preferences/shared_preferences.dart';

import 'terminal_font.dart';

/// Persisted terminal presentation settings, mirroring the original
/// SharedPreferences-backed `TerminalSettingsStore` (key "terminal_settings").
class TerminalSettingsStore {
  TerminalSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _fontSizeKey = 'font_size';
  static const _fontFamilyKey = 'font_family';
  static const _keepAliveKey = 'keep_alive_service_enabled';

  double get fontSize => (_prefs.getDouble(_fontSizeKey) ??
          TerminalFontDefaults.defaultSize)
      .clamp(TerminalFontDefaults.minSize, TerminalFontDefaults.maxSize);

  Future<void> setFontSize(double size) async {
    await _prefs.setDouble(
        _fontSizeKey,
        size.clamp(TerminalFontDefaults.minSize,
            TerminalFontDefaults.maxSize));
  }

  TerminalFont get fontFamily {
    final stored = _prefs.getString(_fontFamilyKey);
    if (stored == null) {
      return TerminalFont.system;
    }
    return TerminalFont.values.firstWhere(
      (f) => f.label == stored,
      orElse: () => TerminalFont.system,
    );
  }

  Future<void> setFontFamily(TerminalFont font) async {
    await _prefs.setString(_fontFamilyKey, font.label);
  }

  bool get keepAliveEnabled => _prefs.getBool(_keepAliveKey) ?? false;

  Future<void> setKeepAliveEnabled(bool value) async {
    await _prefs.setBool(_keepAliveKey, value);
  }
}