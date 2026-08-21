/// Keeps the app alive in the background while SSH sessions are active.
///
/// Android uses a foreground service (opt-in, mirrors the original
/// `SshKeepAliveService`); Windows has nothing to do since the process stays
/// alive while any window is open. See `platform/background_keep_alive_android.dart`
/// and `platform/background_keep_alive_windows.dart` for the two
/// implementations, and `platform/platform_services.dart` for how the
/// correct one is chosen at runtime.
abstract class BackgroundKeepAlive {
  /// Must be called once during startup (main) so the onStart callback is
  /// registered before any service start.
  Future<void> init();

  Future<void> start();
  Future<void> stop();
}