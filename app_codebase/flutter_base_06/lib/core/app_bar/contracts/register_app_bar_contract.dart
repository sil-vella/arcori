/// Typed AppBar widget registration for modules and screens.
///
/// Layout (owned by [ShellAppBar]):
///   [nav back — reserved] | left | center | right | overflow | [nav menu — reserved]
///
/// Rules:
/// 1. [AppBarTitle] defaults to [AppBarSlot.center] and [AppBarLifetime.screen].
/// 2. [AppBarLifetime.screen] items are registered via [AppBarRegistrar] only.
/// 3. [AppBarLifetime.permanent] and [conditional] items use [AppBarSink] at module startup.
/// 4. Nav back / hamburger are reserved slots — configured via [ShellNavControls], not items.
library;

import 'package:flutter/material.dart';

enum AppBarSlot { left, center, right }

enum AppBarLifetime { screen, permanent, conditional }

sealed class AppBarItem {
  const AppBarItem({
    required this.slot,
    required this.lifetime,
    this.priority = 0,
    this.visibleWhen,
  });

  final AppBarSlot slot;
  final AppBarLifetime lifetime;
  /// Lower values stay visible longer when space is tight.
  final int priority;
  final bool Function(BuildContext context)? visibleWhen;
}

/// Screen title: optional leading icon and text. Defaults to center + screen lifetime.
final class AppBarTitle extends AppBarItem {
  const AppBarTitle({
    this.text,
    this.icon,
    super.slot = AppBarSlot.center,
    super.lifetime = AppBarLifetime.screen,
    super.priority = 0,
    super.visibleWhen,
  }) : assert(text != null || icon != null);

  final String? text;
  final IconData? icon;
}

/// Tappable toolbar control with optional label.
final class AppBarAction extends AppBarItem {
  const AppBarAction({
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
    super.slot = AppBarSlot.right,
    super.lifetime = AppBarLifetime.screen,
    super.priority = 10,
    super.visibleWhen,
  });

  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback onTap;
}

/// Reserved shell navigation controls on the AppBar edges (not registered items).
class ShellNavControls {
  const ShellNavControls({
    this.showBack = false,
    this.onBack,
    required this.onMenu,
    this.menuTooltip,
  });

  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback onMenu;
  final String? menuTooltip;
}

abstract interface class AppBarSink {
  void addItems(List<AppBarItem> items);
}
