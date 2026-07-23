import 'package:flutter/material.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';

void registerWsDemoDrawer(AppDrawerSink drawer) {
  drawer.addDestinations([
    const AppDrawerDestination(
      path: AppPaths.wsDemo,
      label: 'WS Demo',
      icon: Icons.cable_outlined,
      selectedIcon: Icons.cable,
    ),
  ]);
}
