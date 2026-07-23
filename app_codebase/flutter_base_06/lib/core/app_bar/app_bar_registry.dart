/// Collects permanent / conditional [AppBarItem] entries from modules.
library;

import 'contracts/register_app_bar_contract.dart';

final AppBarSink appBarSink = _AppBarRegistry._instance;

void resetAppBarRegistry() => _AppBarRegistry._instance.clear();

List<AppBarItem> get appBarModuleItems =>
    List<AppBarItem>.unmodifiable(_AppBarRegistry._instance._items);

class _AppBarRegistry implements AppBarSink {
  _AppBarRegistry._();

  static final _AppBarRegistry _instance = _AppBarRegistry._();

  final List<AppBarItem> _items = [];

  void clear() => _items.clear();

  @override
  void addItems(List<AppBarItem> items) => _items.addAll(items);
}
