import 'package:flutter/material.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';

void registerExampleModuleDrawer(AppDrawerSink drawer) {
  drawer.addDestinations(const [
    AppDrawerDestination(
      path: AppPaths.exampleModule,
      label: 'Example module',
      icon: Icons.extension_outlined,
      selectedIcon: Icons.extension,
    ),
  ]);
}
