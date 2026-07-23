import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'contracts/register_app_bar_contract.dart';

class _ScreenScope {
  _ScreenScope({required this.id, required this.items});

  final Object id;
  final List<AppBarItem> items;
}

/// Merges module items and per-screen scopes for [ShellAppBar].
class AppBarController extends ChangeNotifier {
  final List<AppBarItem> _permanent = [];
  final List<_ScreenScope> _screenStack = [];

  void reset() {
    _permanent.clear();
    _screenStack.clear();
    _notify();
  }

  void setModuleItems(List<AppBarItem> items) {
    _permanent
      ..clear()
      ..addAll(items);
    _notify();
  }

  void pushScreenScope(Object scopeId, List<AppBarItem> items) {
    _screenStack.add(_ScreenScope(id: scopeId, items: items));
    _notify();
  }

  void popTopScreenScope() {
    if (_screenStack.isEmpty) {
      return;
    }
    _screenStack.removeLast();
    _notify();
  }

  void popScreenScope(Object scopeId) {
    final index = _screenStack.indexWhere((s) => s.id == scopeId);
    if (index == -1) {
      return;
    }
    _screenStack.removeAt(index);
    _notify();
  }

  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  List<AppBarItem> itemsFor(BuildContext context) {
    final merged = <AppBarItem>[
      ..._permanent,
      if (_screenStack.isNotEmpty) ..._screenStack.last.items,
    ];
    return merged
        .where((item) => item.visibleWhen?.call(context) ?? true)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }
}

final AppBarController appBarController = AppBarController();

void resetAppBarController() => appBarController.reset();
