import 'package:flutter/material.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';

void registerVeloraDrawer(AppDrawerSink drawer) {
  drawer.addDestinations(const [
    AppDrawerDestination(
      path: AppPaths.velora,
      label: 'Velora',
      icon: Icons.public_outlined,
      selectedIcon: Icons.public,
    ),
  ]);
}
