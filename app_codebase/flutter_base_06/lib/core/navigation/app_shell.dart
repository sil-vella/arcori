import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_bar/app_bar_controller.dart';
import '../app_bar/app_bar_scope.dart';
import '../app_bar/shell_app_bar.dart';
import '../app_bar/contracts/register_app_bar_contract.dart';
import '../bottom_nav/bottom_nav_controller.dart';
import '../bottom_nav/bottom_nav_scope.dart';
import '../bottom_nav/shell_bottom_bar.dart';
import '../screen/shell_chrome_controller.dart';
import '../screen/shell_chrome_scope.dart';
import '../theme/theme.dart';
import '../widgets/app_chrome.dart';
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

    return ShellChromeScope(
      controller: shellChromeController,
      child: BottomNavScope(
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
            child: ListenableBuilder(
              listenable: shellChromeController,
              builder: (context, _) {
                return Scaffold(
                  key: _scaffoldKey,
                  extendBodyBehindAppBar:
                      shellChromeController.extendBodyBehindAppBar,
                  appBar: ShellAppBar(
                    controller: appBarController,
                    shellNavControls: ShellNavControls(
                      showBack: Nav.canPop(context),
                      onBack: () => Nav.pop(context),
                      onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                      menuTooltip: MaterialLocalizations.of(context)
                          .openAppDrawerTooltip,
                    ),
                  ),
                  drawer: showDrawer
                      ? Drawer(
                          backgroundColor: AppChrome.canvasBase,
                          surfaceTintColor: Colors.transparent,
                          child: Theme(
                            data: AppTheme.dark,
                            child: DefaultTextStyle.merge(
                              style: TextStyle(color: AppChrome.onSurface),
                              child: IconTheme.merge(
                                data: IconThemeData(
                                  color: AppChrome.onSurfaceMuted,
                                ),
                                child: SafeArea(
                                  child: Builder(
                                    builder: (drawerContext) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (header != null)
                                            header.builder(drawerContext),
                                          if (header != null &&
                                              (destinations.isNotEmpty ||
                                                  bottomItems.isNotEmpty))
                                            Divider(
                                              indent: AppSpacing.lg,
                                              endIndent: AppSpacing.lg,
                                              color: AppChrome.panelBorder,
                                            ),
                                          Expanded(
                                            child: ListView(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: AppSpacing.sm,
                                                vertical: AppSpacing.xs,
                                              ),
                                              children: [
                                                for (var i = 0;
                                                    i < destinations.length;
                                                    i++)
                                                  ListTile(
                                                    leading: Icon(
                                                      selectedIndex == i
                                                          ? destinations[i]
                                                              .selectedIcon
                                                          : destinations[i]
                                                              .icon,
                                                      color: selectedIndex == i
                                                          ? AppChrome
                                                              .accentGold
                                                          : AppChrome
                                                              .onSurfaceMuted,
                                                    ),
                                                    title: Text(
                                                      destinations[i].label,
                                                      style: drawerContext
                                                          .appTypography.menu
                                                          .copyWith(
                                                        color: selectedIndex ==
                                                                i
                                                            ? AppChrome
                                                                .onSurface
                                                            : AppChrome
                                                                .onSurfaceMuted,
                                                      ),
                                                    ),
                                                    selected:
                                                        selectedIndex == i,
                                                    selectedTileColor: AppChrome
                                                        .accentGold
                                                        .withValues(
                                                            alpha: 0.12),
                                                    onTap: () =>
                                                        Nav.pushFromDrawer(
                                                      drawerContext,
                                                      destinations[i].path,
                                                      scaffold: _scaffoldKey
                                                          .currentState,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (bottomItems.isNotEmpty) ...[
                                            Divider(
                                              indent: AppSpacing.lg,
                                              endIndent: AppSpacing.lg,
                                              color: AppChrome.panelBorder,
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                AppSpacing.sm,
                                                AppSpacing.xs,
                                                AppSpacing.sm,
                                                AppSpacing.sm,
                                              ),
                                              child: Wrap(
                                                spacing: AppSpacing.xs,
                                                runSpacing: AppSpacing.xs,
                                                alignment:
                                                    WrapAlignment.start,
                                                children: [
                                                  for (final item
                                                      in bottomItems)
                                                    IconButton(
                                                      icon: Icon(
                                                        item.icon,
                                                        color: AppChrome
                                                            .onSurfaceMuted,
                                                      ),
                                                      tooltip: item.tooltip,
                                                      onPressed: () =>
                                                          Nav.pushFromDrawer(
                                                        drawerContext,
                                                        item.path,
                                                        scaffold: _scaffoldKey
                                                            .currentState,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                  bottomNavigationBar:
                      ShellBottomBar(controller: bottomNavController),
                  body: widget.child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
