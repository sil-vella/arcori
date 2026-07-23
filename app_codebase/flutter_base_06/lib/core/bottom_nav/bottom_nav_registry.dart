/// Collects per-module route scopes for bottom action bar enforcement.
library;

import 'contracts/register_bottom_nav_contract.dart';

final BottomNavScopeSink bottomNavScopeSink = _BottomNavRegistry._instance;

void resetBottomNavRegistry() => _BottomNavRegistry._instance.clear();

List<BottomNavModuleScope> get bottomNavModuleScopes =>
    List<BottomNavModuleScope>.unmodifiable(_BottomNavRegistry._instance._scopes);

class _BottomNavRegistry implements BottomNavScopeSink {
  _BottomNavRegistry._();

  static final _BottomNavRegistry _instance = _BottomNavRegistry._();

  final List<BottomNavModuleScope> _scopes = [];

  void clear() => _scopes.clear();

  @override
  void registerScope({
    required String moduleId,
    required List<String> pathPrefixes,
  }) {
    _scopes.add(
      BottomNavModuleScope(moduleId: moduleId, pathPrefixes: pathPrefixes),
    );
  }
}
