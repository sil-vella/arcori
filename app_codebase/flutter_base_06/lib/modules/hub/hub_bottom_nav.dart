import 'package:flutter/material.dart';

import '../../core/bottom_nav/contracts/register_bottom_nav_contract.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/app_paths.dart';

/// Shared Home hub sink: Trove • PLAY • Market ([BOTTOM_NAV_REGISTRATION.md]).
const hubSinkBottomNavModuleId = 'hub_sink';

void registerHubSinkBottomNavScope(BottomNavScopeSink sink) {
  sink.registerScope(
    moduleId: hubSinkBottomNavModuleId,
    pathPrefixes: [
      AppPaths.home,
      AppPaths.trove,
      AppPaths.play,
      AppPaths.market,
    ],
  );
}

/// Bottom sink items for hub screens. Uses [Nav.go] so sink taps replace.
List<BottomNavItem> hubSinkBottomNavItems(BuildContext context) {
  final loc = Nav.matchedLocation(context).split('?').first;

  return [
    BottomNavAction(
      icon: loc == AppPaths.trove
          ? Icons.inventory_2
          : Icons.inventory_2_outlined,
      label: 'Trove',
      tooltip: 'Trove',
      onTap: () {
        if (loc == AppPaths.trove) return;
        Nav.go(context, AppPaths.trove);
      },
    ),
    BottomNavAction(
      icon: loc == AppPaths.play
          ? Icons.sports_esports
          : Icons.sports_esports_outlined,
      label: 'PLAY',
      tooltip: 'Play',
      onTap: () {
        if (loc == AppPaths.play) return;
        Nav.go(context, AppPaths.play);
      },
    ),
    BottomNavAction(
      icon: loc == AppPaths.market ? Icons.storefront : Icons.storefront_outlined,
      label: 'Market',
      tooltip: 'Market',
      onTap: () {
        if (loc == AppPaths.market) return;
        Nav.go(context, AppPaths.market);
      },
    ),
  ];
}
