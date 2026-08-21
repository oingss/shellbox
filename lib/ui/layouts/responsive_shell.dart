import 'package:flutter/material.dart';

import '../../features/home/home_screen.dart';
import 'desktop/desktop_layout.dart';
import 'mobile/mobile_layout.dart';

/// Chooses mobile vs. desktop shell by the available width (<600dp = mobile),
/// mirroring the original `LocalIsExpandedScreen` breakpoint.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return const MobileLayout();
        }
        return DesktopLayout(
          child: const HomeScreen(),
        );
      },
    );
  }
}