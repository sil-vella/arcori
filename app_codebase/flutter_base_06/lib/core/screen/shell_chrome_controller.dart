import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Shell layout flags requested by screen templates (e.g. extend body under AppBar).
class ShellChromeController extends ChangeNotifier {
  final List<_ChromeScope> _stack = [];

  bool get extendBodyBehindAppBar {
    if (_stack.isEmpty) return false;
    return _stack.last.extendBodyBehindAppBar;
  }

  /// AppBar title / back / menu tint. Null = theme [ColorScheme.onSurface].
  Color? get appBarForeground {
    if (_stack.isEmpty) return null;
    for (var i = _stack.length - 1; i >= 0; i--) {
      final color = _stack[i].appBarForeground;
      if (color != null) return color;
    }
    return null;
  }

  void reset() {
    _stack.clear();
    _notify();
  }

  void pushScope(
    Object scopeId, {
    required bool extendBodyBehindAppBar,
    Color? appBarForeground,
  }) {
    _stack.add(
      _ChromeScope(
        id: scopeId,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        appBarForeground: appBarForeground,
      ),
    );
    _notify();
  }

  void popScope(Object scopeId) {
    final index = _stack.indexWhere((s) => s.id == scopeId);
    if (index == -1) return;
    _stack.removeAt(index);
    _notify();
  }

  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
}

class _ChromeScope {
  _ChromeScope({
    required this.id,
    required this.extendBodyBehindAppBar,
    this.appBarForeground,
  });

  final Object id;
  final bool extendBodyBehindAppBar;
  final Color? appBarForeground;
}

final ShellChromeController shellChromeController = ShellChromeController();

void resetShellChromeController() => shellChromeController.reset();
