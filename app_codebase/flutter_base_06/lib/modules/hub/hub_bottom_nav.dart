import 'package:flutter/material.dart';

import '../../core/bottom_nav/contracts/register_bottom_nav_contract.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/app_paths.dart';
import '../../core/widgets/app_mark_icon.dart';

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
      icon: Icons.inventory_2_outlined,
      iconAsset: AppMarks.trove,
      label: 'Trove',
      tooltip: 'Trove',
      onTap: () {
        if (loc == AppPaths.trove) return;
        Nav.go(context, AppPaths.trove);
      },
    ),
    BottomNavAction(
      icon: Icons.sports_martial_arts,
      iconAsset: AppMarks.arena,
      label: 'Match',
      tooltip: 'Match',
      emphasized: true,
      onTap: () {
        if (loc == AppPaths.play) return;
        Nav.go(context, AppPaths.play);
      },
    ),
    BottomNavAction(
      icon: Icons.storefront_outlined,
      iconAsset: AppMarks.market,
      label: 'Market',
      tooltip: 'Market',
      onTap: () {
        if (loc == AppPaths.market) return;
        Nav.go(context, AppPaths.market);
      },
    ),
  ];
}
