import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../navigation/app_navigation.dart';
import 'contracts/register_bottom_nav_contract.dart';

class _ScreenScope {
  _ScreenScope({
    required this.id,
    required this.moduleId,
    required this.items,
  });

  final Object id;
  final String moduleId;
  final List<BottomNavItem> items;
}

/// Merges module scopes and per-screen registrars for [ShellBottomBar].
class BottomNavController extends ChangeNotifier {
  final Map<String, BottomNavModuleScope> _moduleScopes = {};
  final List<_ScreenScope> _screenStack = [];

  void reset() {
    _moduleScopes.clear();
    _screenStack.clear();
    _notify();
  }

  void setModuleScopes(List<BottomNavModuleScope> scopes) {
    _moduleScopes
      ..clear()
      ..addEntries(scopes.map((s) => MapEntry(s.moduleId, s)));
    _notify();
  }

  void pushScreenScope(
    Object scopeId,
    String moduleId,
    List<BottomNavItem> items,
  ) {
    _screenStack.add(
      _ScreenScope(id: scopeId, moduleId: moduleId, items: items),
    );
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

  BottomNavModuleScope? moduleScopeFor(String moduleId) =>
      _moduleScopes[moduleId];

  static bool pathMatchesLocation(String location, String prefix) {
    final normalized = location.isEmpty ? '/' : location;
    return normalized == prefix || normalized.startsWith('$prefix/');
  }

  static bool locationMatchesScope(String location, BottomNavModuleScope scope) {
    for (final prefix in scope.pathPrefixes) {
      if (pathMatchesLocation(location, prefix)) {
        return true;
      }
    }
    return false;
  }

  List<BottomNavItem> itemsFor(BuildContext context) {
    if (_screenStack.isEmpty) {
      return const [];
    }

    final scope = _screenStack.last;
    final moduleScope = _moduleScopes[scope.moduleId];
    if (moduleScope == null) {
      assert(
        () {
          return false;
        }(),
        'BottomNavRegistrar moduleId "${scope.moduleId}" has no registered scope. '
        'Call bottomNavScopeSink.registerScope at module startup.',
      );
      return const [];
    }

    final location = Nav.matchedLocation(context);
    if (!locationMatchesScope(location, moduleScope)) {
      return const [];
    }

    return scope.items
        .where((item) => item.visibleWhen?.call(context) ?? true)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  String? activeModuleId() =>
      _screenStack.isEmpty ? null : _screenStack.last.moduleId;
}

final BottomNavController bottomNavController = BottomNavController();

void resetBottomNavController() => bottomNavController.reset();
