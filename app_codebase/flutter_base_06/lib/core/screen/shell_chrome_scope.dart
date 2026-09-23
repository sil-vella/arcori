import 'package:flutter/widgets.dart';

import 'shell_chrome_controller.dart';

/// Exposes [ShellChromeController] to registrars without listening during build.
class ShellChromeScope extends InheritedWidget {
  const ShellChromeScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final ShellChromeController controller;

  static ShellChromeController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ShellChromeScope>();
    assert(scope != null, 'ShellChromeScope not found above $context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(ShellChromeScope oldWidget) =>
      controller != oldWidget.controller;
}
