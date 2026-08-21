import 'dart:async';
import 'dart:io';

/// Extremely defensive, dependency-free file logger.
///
/// Written specifically to debug native/early-startup crashes on Windows
/// (e.g. exceptions like `c000041d` that happen before Flutter's own error
/// machinery — and even the Dart VM in some cases — has finished
/// initializing). Because of that:
///
///  - This class does NOT depend on path_provider, shared_preferences, or
///    any plugin — plugin channels may not be ready yet, or may be exactly
///    what's crashing. It only uses `dart:io`.
///  - It writes to a `logs/` folder next to the executable
///    (`Platform.resolvedExecutable`), which is always writable for an
///    unpackaged Windows build (no elevation / MSIX sandboxing here).
///  - Every write is flushed synchronously. A buffered/async logger is
///    useless for catching a crash that kills the process a few
///    milliseconds after the log line is "written".
///  - All logging calls are wrapped in their own try/catch so a logging
///    failure can never be the thing that crashes the app.
class FileLogger {
  FileLogger._(this._file);

  static FileLogger? _instance;
  final File _file;

  /// Must be called as the very first line of `main()`, before anything
  /// else — including `WidgetsFlutterBinding.ensureInitialized()` — so that
  /// even a crash during binding initialization gets at least one line
  /// logged ("app process started").
  static FileLogger init() {
    if (_instance != null) return _instance!;
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final logDir = Directory('${exeDir.path}${Platform.pathSeparator}logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final file = File(
        '${logDir.path}${Platform.pathSeparator}shellbox_$timestamp.log',
      );
      // Also maintain a stable "latest.log" for convenience so you don't
      // have to hunt for the newest timestamped file after a crash.
      final latest = File(
        '${logDir.path}${Platform.pathSeparator}latest.log',
      );
      file.writeAsStringSync(
        '=== ShellBox log started ${DateTime.now()} ===\n'
        'exe: ${Platform.resolvedExecutable}\n'
        'os: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n'
        'dart: ${Platform.version}\n\n',
      );
      try {
        if (latest.existsSync()) latest.deleteSync();
      } catch (_) {
        // Non-fatal; skip the convenience copy if we can't replace it.
      }
      _instance = FileLogger._(file);
      _instance!._mirrorTo(latest);
      return _instance!;
    } catch (e) {
      // If we can't even create the log file (e.g. read-only directory),
      // fall back to a no-op logger rather than throwing — logging must
      // never be the reason the app fails to start.
      _instance = FileLogger._(File(''));
      return _instance!;
    }
  }

  File? _mirror;
  void _mirrorTo(File mirror) {
    _mirror = mirror;
    try {
      mirror.writeAsStringSync(_file.readAsStringSync());
    } catch (_) {}
  }

  static FileLogger get instance => _instance ?? init();

  void log(String message, {String level = 'INFO'}) {
    final line = '[${DateTime.now().toIso8601String()}] [$level] $message\n';
    // stdout too, in case the app WAS launched from a console that stays
    // open (doesn't hurt, costs nothing).
    try {
      stdout.write(line);
    } catch (_) {}
    try {
      if (_file.path.isEmpty) return;
      _file.writeAsStringSync(line, mode: FileMode.append, flush: true);
      if (_mirror != null) {
        _mirror!.writeAsStringSync(line, mode: FileMode.append, flush: true);
      }
    } catch (_) {
      // Never let a logging failure crash the app or mask the original
      // error.
    }
  }

  void info(String message) => log(message, level: 'INFO');
  void warn(String message) => log(message, level: 'WARN');

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write(' | error: $error');
    }
    log(buffer.toString(), level: 'ERROR');
    if (stackTrace != null) {
      log(stackTrace.toString(), level: 'STACK');
    }
  }

  String get filePath => _file.path;
}
