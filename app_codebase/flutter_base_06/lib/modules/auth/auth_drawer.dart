import 'package:flutter/material.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';

void registerAuthDrawer(AppDrawerSink drawer) {
  drawer.addDestinations(const [
    AppDrawerDestination(
      path: AppPaths.account,
      label: 'Account',
      icon: Icons.person_outlined,
      selectedIcon: Icons.person,
    ),
  ]);
}
