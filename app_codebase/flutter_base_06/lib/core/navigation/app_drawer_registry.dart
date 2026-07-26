/// Collects drawer placements from modules; [AppShell] reads them at build time.
///
/// Call [resetAppDrawerRegistry] before module registration so tests and restarts
/// do not duplicate entries.
library;

import 'contracts/register_drawer_contract.dart';

final AppDrawerSink appDrawerSink = _AppDrawerRegistry._instance;

void resetAppDrawerRegistry() => _AppDrawerRegistry._instance.clear();

AppDrawerHeader? get appDrawerHeader => _AppDrawerRegistry._instance._header;

List<AppDrawerDestination> get appDrawerDestinations =>
    List<AppDrawerDestination>.unmodifiable(
      _AppDrawerRegistry._instance._destinations,
    );

List<AppDrawerBottomItem> get appDrawerBottomItems =>
    List<AppDrawerBottomItem>.unmodifiable(
      _AppDrawerRegistry._instance._bottomItems,
    );

class _AppDrawerRegistry implements AppDrawerSink {
  _AppDrawerRegistry._();

  static final _AppDrawerRegistry _instance = _AppDrawerRegistry._();

  AppDrawerHeader? _header;
  final List<AppDrawerDestination> _destinations = [];
  final List<AppDrawerBottomItem> _bottomItems = [];

  void clear() {
    _header = null;
    _destinations.clear();
    _bottomItems.clear();
  }

  @override
  void setHeader(AppDrawerHeader header) {
    assert(
      _header == null,
      'AppDrawerSink.setHeader called more than once; only one drawer header is allowed',
    );
    _header = header;
  }

  @override
  void addDestinations(List<AppDrawerDestination> destinations) =>
      _destinations.addAll(destinations);

  @override
  void addBottomItems(List<AppDrawerBottomItem> items) =>
      _bottomItems.addAll(items);
}
