import 'package:flutter/material.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';

void registerMuseumDrawer(AppDrawerSink drawer) {
  drawer.addDestinations(const [
    AppDrawerDestination(
      path: AppPaths.museum,
      label: 'Museum',
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance,
    ),
  ]);
}
