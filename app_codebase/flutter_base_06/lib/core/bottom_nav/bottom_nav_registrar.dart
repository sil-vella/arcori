import 'package:flutter/widgets.dart';

import 'bottom_nav_controller.dart';
import 'bottom_nav_scope.dart';
import 'contracts/register_bottom_nav_contract.dart';

/// Registers [items] for the lifetime of this widget (screen-scoped bottom actions).
class BottomNavRegistrar extends StatefulWidget {
  const BottomNavRegistrar({
    required this.moduleId,
    required this.items,
    required this.child,
    super.key,
  });

  final String moduleId;
  final List<BottomNavItem> items;
  final Widget child;

  @override
  State<BottomNavRegistrar> createState() => _BottomNavRegistrarState();
}

class _BottomNavRegistrarState extends State<BottomNavRegistrar> {
  BottomNavController? _controller;
  var _registered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = BottomNavScope.read(context);
    if (!_registered) {
      _registered = true;
      _controller!.pushScreenScope(
        this,
        widget.moduleId,
        widget.items,
      );
    }
  }

  @override
  void didUpdateWidget(covariant BottomNavRegistrar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_registered &&
        (oldWidget.items != widget.items ||
            oldWidget.moduleId != widget.moduleId) &&
        _controller != null) {
      _controller!.popScreenScope(this);
      _controller!.pushScreenScope(
        this,
        widget.moduleId,
        widget.items,
      );
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
