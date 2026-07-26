import 'package:flutter/material.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';

void registerAuthDrawer(AppDrawerSink drawer) {
  drawer.addBottomItems(const [
    AppDrawerBottomItem(
      path: AppPaths.account,
      icon: Icons.settings_outlined,
      tooltip: 'Account',
    ),
  ]);
}
