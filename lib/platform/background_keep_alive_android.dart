import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/services/background_keep_alive.dart';

const _keepAliveChannelId = 'ssh_keep_alive';
const _keepAliveNotificationId = 888;

/// Android [BackgroundKeepAlive] implementation, driving the foreground
/// service from the endorsed `flutter_background_service` plugin (a
/// permanent notification is required by Android for long-running
/// background sockets — mirrors the original `SshKeepAliveService`).
///
/// IMPORTANT: this file must ONLY be imported from Android-only code paths.
/// `flutter_background_service`'s federated plugin family only ships
/// `flutter_background_service_android` and `flutter_background_service_ios`
/// implementations — there is no Windows backend. Importing this file (or
/// the plugin package) from any code that gets compiled into the Windows
/// build will break `flutter build windows` / `flutter run -d windows`.
/// See `background_keep_alive_windows.dart` and `platform_services.dart`
/// for how the two are kept apart.
class AndroidBackgroundKeepAlive implements BackgroundKeepAlive {
  AndroidBackgroundKeepAlive();

  bool _configured = false;

  @override
  Future<void> init() async {
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _keepAliveChannelId,
          'SSH 保活',
          description: 'SSH 连接保持服务的常驻通知',
          importance: Importance.low,
        ));

    final service = FlutterBackgroundService();
    await service.configure(
      iosConfiguration: IosConfiguration(autoStart: false),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: false,
        notificationChannelId: _keepAliveChannelId,
        initialNotificationTitle: 'ShellBox',
        initialNotificationContent: 'SSH 连接保持中',
        foregroundServiceNotificationId: _keepAliveNotificationId,
      ),
    );
    _configured = true;
  }

  @override
  Future<void> start() async {
    if (!_configured) {
      await init();
    }
    final service = FlutterBackgroundService();
    await service.startService();
  }

  @override
  Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }
}

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  service.on('stop').listen((event) {
    service.stopSelf();
  });
}
