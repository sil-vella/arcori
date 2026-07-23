import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_bar/app_bar_controller.dart';
import '../app_bar/app_bar_scope.dart';
import '../app_bar/shell_app_bar.dart';
import '../app_bar/contracts/register_app_bar_contract.dart';
import '../bottom_nav/bottom_nav_controller.dart';
import '../bottom_nav/bottom_nav_scope.dart';
import '../bottom_nav/shell_bottom_bar.dart';
import 'app_drawer_registry.dart';
import 'app_navigation.dart';
import 'contracts/register_drawer_contract.dart';

/// App chrome: one [Scaffold] owns the [NavigationDrawer] so [openDrawer] and M3
/// navigation patterns work (avoid a drawer on an outer shell and a second [Scaffold] per route).
///
/// Drawer rows come from [appDrawerDestinations] (populated via [AppDrawerSink] in each module).
/// AppBar slots (left / center / right) come from [core/app_bar]; back and menu are reserved nav chrome.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // [ShellRoute] swaps [child] without always rebuilding this [State]; re-sync chrome.
    if (oldWidget.child != widget.child) {
      _scheduleRebuild();
    }
  }

  void _scheduleRebuild() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  int _indexForLocation(String location, List<AppDrawerDestination> destinations) {
    final normalized = location.isEmpty ? '/' : location;
    for (var i = 0; i < destinations.length; i++) {
      final p = destinations[i].path;
      if (normalized == p || normalized.startsWith('$p/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = Nav.matchedLocation(context);
    final destinations = appDrawerDestinations;
    final selectedIndex = destinations.isEmpty
        ? null
        : _indexForLocation(location, destinations);

    return BottomNavScope(
      controller: bottomNavController,
      child: AppBarScope(
        controller: appBarController,
        child: PopScope(
          canPop: !Nav.canPop(context),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && Nav.canPop(context)) {
              Nav.pop(context);
            }
          },
          child: Scaffold(
            key: _scaffoldKey,
            appBar: ShellAppBar(
              controller: appBarController,
              shellNavControls: ShellNavControls(
                showBack: Nav.canPop(context),
                onBack: () => Nav.pop(context),
                onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                menuTooltip:
                    MaterialLocalizations.of(context).openAppDrawerTooltip,
              ),
            ),
            drawer: destinations.isEmpty
                ? null
                : NavigationDrawer(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      Nav.pushFromDrawer(
                        context,
                        destinations[index].path,
                        scaffold: _scaffoldKey.currentState,
                      );
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 16, 10),
                        child: Text(
                          'Arcori',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const Divider(indent: 28, endIndent: 28),
                      for (final d in destinations)
                        NavigationDrawerDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
            bottomNavigationBar:
                ShellBottomBar(controller: bottomNavController),
            body: widget.child,
          ),
        ),
      ),
    );
  }
}
