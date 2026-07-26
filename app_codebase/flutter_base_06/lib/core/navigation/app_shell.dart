import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_bar/app_bar_controller.dart';
import '../app_bar/app_bar_scope.dart';
import '../app_bar/shell_app_bar.dart';
import '../app_bar/contracts/register_app_bar_contract.dart';
import '../bottom_nav/bottom_nav_controller.dart';
import '../bottom_nav/bottom_nav_scope.dart';
import '../bottom_nav/shell_bottom_bar.dart';
import '../theme/theme.dart';
import 'app_drawer_registry.dart';
import 'app_navigation.dart';
import 'contracts/register_drawer_contract.dart';

/// App chrome: one [Scaffold] owns the drawer so [openDrawer] and M3 navigation
/// patterns work (avoid a drawer on an outer shell and a second [Scaffold] per route).
///
/// Placements from [AppDrawerSink]: optional header, destinations, bottom icon row.
/// AppBar slots come from [core/app_bar]; back and menu are reserved nav chrome.
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

  int? _indexForLocation(
    String location,
    List<AppDrawerDestination> destinations,
  ) {
    final normalized = location.isEmpty ? '/' : location;
    for (var i = 0; i < destinations.length; i++) {
      final p = destinations[i].path;
      if (normalized == p || normalized.startsWith('$p/')) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final location = Nav.matchedLocation(context);
    final header = appDrawerHeader;
    final destinations = appDrawerDestinations;
    final bottomItems = appDrawerBottomItems;
    final selectedIndex = destinations.isEmpty
        ? null
        : _indexForLocation(location, destinations);
    final showDrawer =
        header != null || destinations.isNotEmpty || bottomItems.isNotEmpty;

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
            drawer: showDrawer
                ? Drawer(
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (header != null) header.builder(context),
                          if (header != null &&
                              (destinations.isNotEmpty ||
                                  bottomItems.isNotEmpty))
                            const Divider(indent: 28, endIndent: 28),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                for (var i = 0; i < destinations.length; i++)
                                  ListTile(
                                    leading: Icon(
                                      selectedIndex == i
                                          ? destinations[i].selectedIcon
                                          : destinations[i].icon,
                                    ),
                                    title: Text(destinations[i].label),
                                    selected: selectedIndex == i,
                                    onTap: () => Nav.pushFromDrawer(
                                      context,
                                      destinations[i].path,
                                      scaffold: _scaffoldKey.currentState,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (bottomItems.isNotEmpty) ...[
                            const Divider(indent: 28, endIndent: 28),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.sm,
                                AppSpacing.xs,
                                AppSpacing.sm,
                                AppSpacing.sm,
                              ),
                              child: Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                alignment: WrapAlignment.start,
                                children: [
                                  for (final item in bottomItems)
                                    IconButton(
                                      icon: Icon(item.icon),
                                      tooltip: item.tooltip,
                                      onPressed: () => Nav.pushFromDrawer(
                                        context,
                                        item.path,
                                        scaffold: _scaffoldKey.currentState,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : null,
            bottomNavigationBar:
                ShellBottomBar(controller: bottomNavController),
            body: widget.child,
          ),
        ),
      ),
    );
  }
}
