import 'package:flutter/material.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';

void registerTasksDrawer(AppDrawerSink drawer) {
  drawer.addDestinations(const [
    AppDrawerDestination(
      path: AppPaths.tasks,
      label: 'Tasks',
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
    ),
  ]);
}
