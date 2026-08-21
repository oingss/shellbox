import 'package:flutter/material.dart';

import '../../../features/settings/settings_screen.dart';

/// Wide form factor: persistent navigation rail + content pane.
class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key, required this.child});

  final Widget child;

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      widget.child,
      const SettingsScreen(),
    ];
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dns_outlined),
                selectedIcon: Icon(Icons.dns),
                label: Text('服务器'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: IndexedStack(index: _index, children: pages)),
        ],
      ),
    );
  }
}