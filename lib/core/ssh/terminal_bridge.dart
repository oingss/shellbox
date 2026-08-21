import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

/// Bridges one live SSH shell to an xterm [Terminal], mirroring the flow used
/// by the original app's `SshTerminalBridge`.
///
/// Wiring (confirmed against the xterm/dartssh2 official example):
///   - remote stdout (utf8)        -> terminal.write(...)
///   - local keystrokes            -> terminal.onOutput -> session.write(...)
///   - viewport resize             -> terminal.onResize -> session.resizeTerminal
class TerminalBridge {
  TerminalBridge(this.terminal, this.session) {
    _sub = session.stdout.cast<List<int>>().transform(utf8.decoder).listen(
          _onRemoteData,
          onDone: _onRemoteClosed,
          onError: _onRemoteError,
        );

    // Push local input to the remote shell.
    terminal.onOutput = (data) {
      try {
session.write(utf8.encode(data));
      } catch (_) {}
    };

    // Report PTY size changes to the remote shell as the viewport resizes.
    terminal.onResize = (w, h, pixelWidth, pixelHeight) {
      session.resizeTerminal(w, h, pixelWidth, pixelHeight);
    };

    // Keep tab title in sync with remote `ESC]0;...` sequences. Redirect
    // through the indirection field so the UI can attach/swap the handler
    // after construction.
    terminal.onTitleChange = (title) => onTitleChange?.call(title);
  }

  final Terminal terminal;
  final SSHSession session;

  StreamSubscription<String>? _sub;

  /// Invoked when the remote process closes the channel (disconnect).
  void Function()? onRemoteClosed;

  /// Invoked when the remote shell sets its window title.
  void Function(String title)? onTitleChange;

  void writeLocal(String data) => session.write(utf8.encode(data));

  void _onRemoteData(String data) {
    // Ignore control-noise before the terminal is ready.
    try {
      terminal.write(data);
    } catch (_) {}
  }

  void _onRemoteClosed() {
    onRemoteClosed?.call();
  }

  void _onRemoteError(Object error, StackTrace st) {
    _onRemoteClosed();
  }

  Future<void> dispose() async {
    onRemoteClosed = null;
    terminal.onOutput = null;
    terminal.onResize = null;
    terminal.onTitleChange = null;
    await _sub?.cancel();
    try {
      session.close();
    } catch (_) {}
  }
}