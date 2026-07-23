import 'package:flutter/material.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';

void registerSampleDrawer(AppDrawerSink drawer) {
  drawer.addDestinations(const [
    AppDrawerDestination(
      path: AppPaths.sample,
      label: 'Sample',
      icon: Icons.widgets_outlined,
      selectedIcon: Icons.widgets,
    ),
  ]);
}
