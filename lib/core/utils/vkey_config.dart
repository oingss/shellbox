import 'dart:convert';

/// Virtual-keyboard keys re-emitted through the SSH session, mirroring the
/// original `VKeyAction` for the two customizable key rows.
enum VKeyAction {
  arrowUp('↑', '上行'),
  arrowDown('↓', '下行'),
  arrowLeft('←', '左移'),
  arrowRight('→', '右移'),
  pageUp('⇞', '上翻页'),
  pageDown('⇟', '下翻页'),
  home('⇱', 'Home'),
  end('⇲', 'End'),
  esc('Esc', 'Esc'),
  tab('⇥', 'Tab'),
  enter('⏎', '回车'),
  backspace('⌫', '退格'),
  toggleCtrl('CTRL', '锁定 Ctrl'),
  toggleAlt('ALT', '锁定 Alt'),
  toggleShift('SHIFT', '锁定 Shift'),
  showKeyboard('⌨', '软键盘'),
  sendText('✎', '发送文本');

  const VKeyAction(this.icon, this.label);

  final String icon;

  /// Chinese label shown in the key editor.
  final String label;

  /// Escape / control sequence for the key when sent to the remote shell.
  String get escape {
    switch (this) {
      case VKeyAction.arrowUp:
        return '\u001b[A';
      case VKeyAction.arrowDown:
        return '\u001b[B';
      case VKeyAction.arrowRight:
        return '\u001b[C';
      case VKeyAction.arrowLeft:
        return '\u001b[D';
      case VKeyAction.pageUp:
        return '\u001b[5~';
      case VKeyAction.pageDown:
        return '\u001b[6~';
      case VKeyAction.home:
        return '\u001b[H';
      case VKeyAction.end:
        return '\u001b[F';
      case VKeyAction.esc:
        return '\u001b';
      case VKeyAction.tab:
        return '\t';
      case VKeyAction.enter:
        return '\r';
      case VKeyAction.backspace:
        return '\u007f';
      default:
        return '';
    }
  }

  static VKeyAction fromName(String name) => VKeyAction.values.firstWhere(
        (a) => a.name == name,
        orElse: () => VKeyAction.arrowUp,
      );
}

/// One configurable key row (ordered actions).
class VKeyRow {
  VKeyRow(this.actions);

  final List<VKeyAction> actions;

  List<String> toJson() => actions.map((a) => a.name).toList();

  static VKeyRow fromJson(List<dynamic> raw) => VKeyRow(
        raw.whereType<String>().map(VKeyAction.fromName).toList(),
      );
}

/// Two-row virtual-keyboard configuration + its persistence, mirroring the
/// original `VKeyLayout`/`VKeyLayoutStore` (JSON stored in SharedPreferences).
class VKeyLayoutStore {
  static const persistedKey = 'vkey_layout_v1';

  static const _defaultRow1 = [
    VKeyAction.esc,
    VKeyAction.tab,
    VKeyAction.arrowUp,
    VKeyAction.arrowDown,
    VKeyAction.arrowLeft,
    VKeyAction.arrowRight,
  ];

  static const _defaultRow2 = [
    VKeyAction.toggleCtrl,
    VKeyAction.toggleAlt,
    VKeyAction.toggleShift,
    VKeyAction.pageUp,
    VKeyAction.pageDown,
    VKeyAction.backspace,
    VKeyAction.home,
    VKeyAction.end,
  ];

  static List<VKeyRow> defaults() => [
        VKeyRow(_defaultRow1),
        VKeyRow(_defaultRow2),
      ];

  static List<VKeyRow> fromStoredJson(String? stored) {
    if (stored == null || stored.isEmpty) {
      return defaults();
    }
    try {
      final raw = jsonDecode(stored);
      if (raw is! List || raw.isEmpty) {
        return defaults();
      }
      return raw
          .whereType<List<dynamic>>()
          .map(VKeyRow.fromJson)
          .where((r) => r.actions.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return defaults();
    }
  }

  static String encode(List<VKeyRow> rows) =>
      jsonEncode(rows.map((r) => r.toJson()).toList());
}