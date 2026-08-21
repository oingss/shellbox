import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/utils/file_logger.dart';
import 'core/utils/terminal_settings_store.dart';
import 'platform/platform_services.dart';

// Everything in main() is wrapped in a broad try/catch and run inside
// runZonedGuarded specifically to debug otherwise-silent early-startup
// crashes on Windows (e.g. exit code c000041d with no console output).
// The log file lives at <exe folder>/logs/latest.log — see
// core/utils/file_logger.dart for why it avoids any plugin dependency.
void main() {
  final logger = FileLogger.init();
  logger.info('main() entered');

  runZonedGuarded(
    () async {
      logger.info('runZonedGuarded body started');

      FlutterError.onError = (FlutterErrorDetails details) {
        logger.error(
          'FlutterError.onError',
          details.exception,
          details.stack,
        );
        FlutterError.presentError(details);
      };

      // Catches errors thrown from the platform dispatcher (e.g. during
      // rendering/frame callbacks) on Flutter versions where this hook is
      // available; harmless no-op signature mismatch is avoided by keeping
      // this call optional and guarded.
      PlatformDispatcher.instance.onError = (error, stack) {
        logger.error('PlatformDispatcher.onError', error, stack);
        return true; // handled — do not let it crash the isolate.
      };

      logger.info('Calling WidgetsFlutterBinding.ensureInitialized()');
      WidgetsFlutterBinding.ensureInitialized();
      logger.info('WidgetsFlutterBinding ready');

      logger.info('Constructing AppServicesImpl()');
      final appServices = AppServicesImpl();
      logger.info('AppServicesImpl constructed');

      logger.info('Calling appServices.keepAlive.init()');
      try {
        await appServices.keepAlive.init();
        logger.info('keepAlive.init() completed');
      } catch (e, st) {
        // Keep-alive is not essential to getting a window on screen; log
        // and continue rather than let this take down the whole app.
        logger.error('keepAlive.init() FAILED (continuing anyway)', e, st);
      }

      logger.info('Calling SharedPreferences.getInstance()');
      final prefs = await SharedPreferences.getInstance();
      logger.info('SharedPreferences ready');

      logger.info('Calling runApp()');
      runApp(ShellBoxApp(
        appServices: appServices,
        terminalSettings: TerminalSettingsStore(prefs),
      ));
      logger.info('runApp() returned (widget tree scheduled)');
    },
    (error, stackTrace) {
      logger.error('Uncaught zone error', error, stackTrace);
    },
  );
}
