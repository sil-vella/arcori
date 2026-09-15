import 'package:flutter/material.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';

void registerAchievementsDrawer(AppDrawerSink drawer) {
  drawer.addDestinations(const [
    AppDrawerDestination(
      path: AppPaths.achievements,
      label: 'Achievements',
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
    ),
  ]);
}
