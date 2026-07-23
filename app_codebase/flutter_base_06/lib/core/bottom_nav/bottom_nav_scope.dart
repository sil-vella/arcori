import 'package:flutter/widgets.dart';

import 'bottom_nav_controller.dart';

/// Exposes [BottomNavController] to registrars without listening during build.
class BottomNavScope extends InheritedWidget {
  const BottomNavScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final BottomNavController controller;

  static BottomNavController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<BottomNavScope>();
    assert(scope != null, 'BottomNavScope not found above $context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(BottomNavScope oldWidget) =>
      controller != oldWidget.controller;
}
