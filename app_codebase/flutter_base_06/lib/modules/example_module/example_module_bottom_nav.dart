import 'package:flutter/material.dart';

import '../../core/bottom_nav/contracts/register_bottom_nav_contract.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/app_paths.dart';

const exampleModuleBottomNavModuleId = 'example_module';

void registerExampleModuleBottomNavScope(BottomNavScopeSink sink) {
  sink.registerScope(
    moduleId: exampleModuleBottomNavModuleId,
    pathPrefixes: [AppPaths.exampleModule],
  );
}

List<BottomNavItem> exampleModuleBottomNavItems(BuildContext context) {
  return [
    BottomNavAction(
      icon: Icons.home_outlined,
      tooltip: 'Go to Home',
      onTap: () => Nav.push(context, AppPaths.home),
    ),
  ];
}
