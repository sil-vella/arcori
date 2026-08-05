import 'package:flutter/material.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';

void registerPlayDrawer(AppDrawerSink drawer) {
  drawer.addDestinations(const [
    AppDrawerDestination(
      path: AppPaths.play,
      label: 'Play',
      icon: Icons.sports_esports_outlined,
      selectedIcon: Icons.sports_esports,
    ),
  ]);
}
