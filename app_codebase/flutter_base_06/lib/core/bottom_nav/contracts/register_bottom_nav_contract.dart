/// Typed bottom action bar registration for modules and screens.
///
/// Layout (owned by [ShellBottomBar]): evenly spaced icon actions with optional
/// overflow menu when space is tight.
///
/// Rules:
/// 1. Bar is hidden by default — no [BottomNavRegistrar] on a screen means no bar.
/// 2. [BottomNavLifetime.screen] items are registered via [BottomNavRegistrar] only.
/// 3. Modules declare allowed route prefixes via [BottomNavScopeSink] at startup.
/// 4. Items render only when the active route matches the registrar's module scope.
library;

import 'package:flutter/material.dart';

enum BottomNavLifetime { screen }

sealed class BottomNavItem {
  const BottomNavItem({
    required this.lifetime,
    this.priority = 0,
    this.visibleWhen,
  });

  final BottomNavLifetime lifetime;
  /// Lower values stay visible longer when space is tight.
  final int priority;
  final bool Function(BuildContext context)? visibleWhen;
}

/// Custom tap handler (connect, toggle, etc.).
final class BottomNavAction extends BottomNavItem {
  const BottomNavAction({
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
    super.lifetime = BottomNavLifetime.screen,
    super.priority = 0,
    super.visibleWhen,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final String? tooltip;
}

/// Navigate within the module; path must match the module's registered prefixes.
final class BottomNavNavigate extends BottomNavItem {
  const BottomNavNavigate({
    required this.icon,
    required this.path,
    this.label,
    this.tooltip,
    super.lifetime = BottomNavLifetime.screen,
    super.priority = 0,
    super.visibleWhen,
  });

  final IconData icon;
  final String path;
  final String? label;
  final String? tooltip;
}

/// Route prefixes a module may attach bottom actions to.
class BottomNavModuleScope {
  const BottomNavModuleScope({
    required this.moduleId,
    required this.pathPrefixes,
  });

  final String moduleId;
  final List<String> pathPrefixes;
}

abstract interface class BottomNavScopeSink {
  void registerScope({
    required String moduleId,
    required List<String> pathPrefixes,
  });
}
