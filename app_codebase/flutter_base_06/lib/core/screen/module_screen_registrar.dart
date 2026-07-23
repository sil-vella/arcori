import 'package:flutter/widgets.dart';

import '../app_bar/app_bar_registrar.dart';
import '../app_bar/contracts/register_app_bar_contract.dart';
import '../bottom_nav/bottom_nav_registrar.dart';
import '../bottom_nav/contracts/register_bottom_nav_contract.dart';

/// Body-only screen wrapper: registers AppBar (and optional bottom nav) with the shell.
///
/// Screens stay body-only; [AppShell] still owns drawer and scaffold.
/// Pass [bottomNavModuleId] + [bottomNavItems] when the module registers a
/// bottom action bar for this screen.
class ModuleScreenRegistrar extends StatelessWidget {
  const ModuleScreenRegistrar({
    required this.appBarItems,
    required this.child,
    this.bottomNavModuleId,
    this.bottomNavItems = const [],
    super.key,
  });

  final List<AppBarItem> appBarItems;
  final String? bottomNavModuleId;
  final List<BottomNavItem> bottomNavItems;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final withAppBar = AppBarRegistrar(items: appBarItems, child: child);

    if (bottomNavModuleId == null || bottomNavItems.isEmpty) {
      return withAppBar;
    }

    return BottomNavRegistrar(
      moduleId: bottomNavModuleId!,
      items: bottomNavItems,
      child: withAppBar,
    );
  }
}
