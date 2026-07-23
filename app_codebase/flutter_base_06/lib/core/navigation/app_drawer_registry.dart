/// Collects [AppDrawerDestination] entries from modules; [AppShell] reads the list at build time.
///
/// Call [resetAppDrawerRegistry] before module registration so tests and restarts do not duplicate
/// entries.
library;

import 'contracts/register_drawer_contract.dart';

final AppDrawerSink appDrawerSink = _AppDrawerRegistry._instance;

void resetAppDrawerRegistry() => _AppDrawerRegistry._instance.clear();

List<AppDrawerDestination> get appDrawerDestinations =>
    List<AppDrawerDestination>.unmodifiable(_AppDrawerRegistry._instance._destinations);

class _AppDrawerRegistry implements AppDrawerSink {
  _AppDrawerRegistry._();

  static final _AppDrawerRegistry _instance = _AppDrawerRegistry._();

  final List<AppDrawerDestination> _destinations = [];

  void clear() => _destinations.clear();

  @override
  void addDestinations(List<AppDrawerDestination> destinations) =>
      _destinations.addAll(destinations);
}
