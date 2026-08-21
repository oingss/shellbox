import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/utils/terminal_settings_store.dart';
import 'platform/platform_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appServices = AppServicesImpl();
  await appServices.keepAlive.init();

  final prefs = await SharedPreferences.getInstance();

  runApp(ShellBoxApp(
    appServices: appServices,
    terminalSettings: TerminalSettingsStore(prefs),
  ));
}