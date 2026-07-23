import 'package:flutter/widgets.dart';

import 'app_bar_controller.dart';
import 'app_bar_scope.dart';
import 'contracts/register_app_bar_contract.dart';

/// Registers [items] for the lifetime of this widget (screen-scoped AppBar widgets).
class AppBarRegistrar extends StatefulWidget {
  const AppBarRegistrar({
    required this.items,
    required this.child,
    super.key,
  });

  final List<AppBarItem> items;
  final Widget child;

  @override
  State<AppBarRegistrar> createState() => _AppBarRegistrarState();
}

class _AppBarRegistrarState extends State<AppBarRegistrar> {
  AppBarController? _controller;
  var _registered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppBarScope.read(context);
    if (!_registered) {
      _registered = true;
      _controller!.pushScreenScope(this, widget.items);
    }
  }

  @override
  void didUpdateWidget(covariant AppBarRegistrar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_registered &&
        oldWidget.items != widget.items &&
        _controller != null) {
      _controller!.popScreenScope(this);
      _controller!.pushScreenScope(this, widget.items);
    }
  }

  @override
  void dispose() {
    if (_registered) {
      _controller?.popScreenScope(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
