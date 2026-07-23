import 'package:flutter/widgets.dart';

import 'app_bar_controller.dart';

/// Exposes [AppBarController] to registrars without listening during build.
class AppBarScope extends InheritedWidget {
  const AppBarScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final AppBarController controller;

  static AppBarController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppBarScope>();
    assert(scope != null, 'AppBarScope not found above $context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(AppBarScope oldWidget) =>
      controller != oldWidget.controller;
}
