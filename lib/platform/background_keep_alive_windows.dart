import '../core/services/background_keep_alive.dart';

/// Windows [BackgroundKeepAlive] implementation.
///
/// A running desktop process is never suspended by the OS just because its
/// window is minimized or unfocused — sockets stay open for as long as the
/// process is alive. The only thing keeping a long-idle SSH connection
/// healthy is the protocol-level keep-alive (`ServerAliveInterval`)
/// configured directly on the `SSHClient` in `core/ssh/ssh_manager.dart`,
/// which applies on every platform. So this implementation is a
/// deliberate, dependency-free no-op — there is no OS-level lifecycle to
/// fight against, and critically, it does NOT import
/// `flutter_background_service` (which has no Windows backend and would
/// break the Windows build if pulled in — see
/// `background_keep_alive_android.dart` for details).
class WindowsBackgroundKeepAlive implements BackgroundKeepAlive {
  const WindowsBackgroundKeepAlive();

  @override
  Future<void> init() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
