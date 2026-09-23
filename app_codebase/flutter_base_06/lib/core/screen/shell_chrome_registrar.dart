import 'package:flutter/widgets.dart';

import 'shell_chrome_controller.dart';
import 'shell_chrome_scope.dart';

/// Registers shell chrome flags for the lifetime of this widget (screen-scoped).
class ShellChromeRegistrar extends StatefulWidget {
  const ShellChromeRegistrar({
    required this.child,
    this.extendBodyBehindAppBar = false,
    this.appBarForeground,
    super.key,
  });

  final bool extendBodyBehindAppBar;

  /// Optional AppBar tint (title, back, menu). Null keeps theme onSurface.
  final Color? appBarForeground;

  final Widget child;

  @override
  State<ShellChromeRegistrar> createState() => _ShellChromeRegistrarState();
}

class _ShellChromeRegistrarState extends State<ShellChromeRegistrar> {
  ShellChromeController? _controller;
  var _registered = false;

  void _push() {
    _controller!.pushScope(
      this,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      appBarForeground: widget.appBarForeground,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = ShellChromeScope.read(context);
    if (!_registered) {
      _registered = true;
      _push();
    }
  }

  @override
  void didUpdateWidget(covariant ShellChromeRegistrar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_registered || _controller == null) return;
    if (oldWidget.extendBodyBehindAppBar != widget.extendBodyBehindAppBar ||
        oldWidget.appBarForeground != widget.appBarForeground) {
      _controller!.popScope(this);
      _push();
    }
  }

  @override
  void dispose() {
    if (_registered) {
      _controller?.popScope(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
