import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/app_services.dart';
import 'core/state/providers.dart';
import 'core/utils/terminal_settings_store.dart';
import 'features/settings/settings_screen.dart';
import 'ui/common/theme.dart';
import 'ui/layouts/responsive_shell.dart';

/// Root widget. [appServices] and [terminalSettings] are injected here by
/// main() so all platform wiring stays in one place.
class ShellBoxApp extends StatelessWidget {
  const ShellBoxApp({
    super.key,
    required this.appServices,
    required this.terminalSettings,
  });

  final AppServices appServices;
  final TerminalSettingsStore terminalSettings;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(appServices),
        terminalSettingsProvider.overrideWithValue(terminalSettings),
      ],
      child: MaterialApp(
        title: 'ShellBox',
        debugShowCheckedModeBanner: false,
        theme: buildShellBoxTheme(),
        home: const ResponsiveShell(),
        routes: {
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}