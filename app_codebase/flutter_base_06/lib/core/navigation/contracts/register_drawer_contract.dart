/// Let feature modules register drawer placements without depending on
/// [AppShell] or the drawer registry implementation. Wired from [registerApplicationModules].
///
/// Placements (layout owned by [AppShell] when wired):
/// 1. **Header** — at most one [AppDrawerHeader]; module owns the widget content.
/// 2. **Destinations** — ordered [AppDrawerDestination] list (primary nav rows).
/// 3. **Bottom** — ordered [AppDrawerBottomItem] icon row at the drawer foot.
///    Items fill left → right; when a row is full, wrap upward. No item limit.
library;

import 'package:flutter/material.dart';

/// Single drawer header slot. Content is built by the registering module.
class AppDrawerHeader {
  const AppDrawerHeader({required this.builder});

  /// Builds the header widget; called by the shell when the drawer opens.
  final WidgetBuilder builder;
}

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

/// One icon in the drawer bottom row; [path] is the same string used in [GoRoute.path].
class AppDrawerBottomItem {
  const AppDrawerBottomItem({
    required this.path,
    required this.icon,
    this.tooltip,
  });

  final String path;
  final IconData icon;
  final String? tooltip;
}

abstract interface class AppDrawerSink {
  /// Registers the single drawer header. Call at most once across all modules.
  void setHeader(AppDrawerHeader header);

  void addDestinations(List<AppDrawerDestination> destinations);

  /// Appends bottom icon-row items. Order = registration order; no limit.
  void addBottomItems(List<AppDrawerBottomItem> items);
}
