import 'dart:io' show Platform;

import '../core/services/app_services.dart';
import '../core/services/background_keep_alive.dart';
import '../core/services/file_picker_service.dart';
import '../core/services/secret_storage.dart';
import 'background_keep_alive_android.dart';
import 'background_keep_alive_windows.dart';
import 'file_picker_impl.dart';
import 'secret_storage_impl.dart';

/// Concrete [AppServices] for Android and Windows.
///
/// NOTE on `keepAlive`: this is chosen with a runtime `Platform.isAndroid`
/// check rather than a Dart conditional import, because Dart's
/// `if (dart.library.xxx)` conditional-import mechanism can only key off
/// which *core* libraries exist (e.g. `dart.library.io` vs
/// `dart.library.html`) — both Android and Windows have `dart:io`, so there
/// is no compile-time signal that distinguishes them. That's fine here
/// because `AndroidBackgroundKeepAlive` and `WindowsBackgroundKeepAlive`
/// live in separate files and neither one is ever *called* on the wrong
/// platform — the important thing (see those files' docs) is that
/// `flutter_background_service` APIs are never invoked outside of Android,
/// since that plugin has no Windows-side implementation registered and
/// calling into it there throws a MissingPluginException at runtime.
class AppServicesImpl implements AppServices {
  AppServicesImpl();

  @override
  final SecretStorage secretStorage = SecureStorageImpl();

  @override
  final BackgroundKeepAlive keepAlive = Platform.isAndroid
      ? AndroidBackgroundKeepAlive()
      : const WindowsBackgroundKeepAlive();

  @override
  final FilePickerService filePicker = PlatformFilePicker();
}
