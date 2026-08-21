/// Mirror of the original `TerminalFont` enum.
enum TerminalFont {
  system('System', null),
  jetBrainsMono('JetBrains Mono', 'JetBrainsMono'),
  firaCode('Fira Code', 'FiraCode'),
  sourceCodePro('Source Code Pro', 'SourceCodePro');

  const TerminalFont(this.label, this.family);

  final String label;

  /// Bundled font-family name declared in pubspec.yaml; null for system font.
  final String? family;
}

abstract interface class TerminalFontDefaults {
  static const minSize = 10.0;
  static const maxSize = 22.0;
  static const defaultSize = 14.0;
}