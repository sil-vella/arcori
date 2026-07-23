/// Let feature modules add primary [NavigationDrawer] destinations without depending on
/// [AppShell] or the drawer registry implementation. Wired from [registerApplicationModules].
library;

import 'package:flutter/material.dart';

/// One row in the app navigation drawer; [path] is the same string used in [GoRoute.path].
class AppDrawerDestination {
  const AppDrawerDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

abstract interface class AppDrawerSink {
  void addDestinations(List<AppDrawerDestination> destinations);
}
