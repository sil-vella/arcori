/// Registry of notification subtype specs — modules register at bootstrap.
library;

import 'contracts/register_notification_subtype_contract.dart';
import 'notification_subtype_spec.dart';

final NotificationSubtypeSink notificationSubtypeSink =
    _NotificationSubtypeRegistry._instance;

void resetNotificationSubtypeRegistry() =>
    _NotificationSubtypeRegistry._instance.clear();

NotificationSubtypeSpec resolveSubtypeSpec({
  required String source,
  String? category,
  String? subtype,
}) {
  return _NotificationSubtypeRegistry._instance.resolve(
    source: source,
    category: category,
    subtype: subtype,
  );
}

Duration interMessageDelayFor({
  required String source,
  String? category,
  String? subtype,
}) {
  final spec = resolveSubtypeSpec(
    source: source,
    category: category,
    subtype: subtype,
  );
  return Duration(milliseconds: spec.interModalDelayMs);
}

class _NotificationSubtypeRegistry implements NotificationSubtypeSink {
  _NotificationSubtypeRegistry._();

  static final _NotificationSubtypeRegistry _instance =
      _NotificationSubtypeRegistry._();

  final Map<String, NotificationSubtypeSpec> _specs = {};

  void clear() => _specs.clear();

  @override
  void registerSubtypes(List<NotificationSubtypeSpec> specs) {
    for (final spec in specs) {
      final key = spec.key;
      if (key.isEmpty || key == '::') {
        continue;
      }
      _specs[key] = spec;
    }
  }

  NotificationSubtypeSpec resolve({
    required String source,
    String? category,
    String? subtype,
  }) {
    final categoryValue = category?.trim() ?? '';
    final subtypeValue = subtype?.trim() ?? '';
    if (categoryValue.isEmpty || subtypeValue.isEmpty) {
      return NotificationSubtypeSpec(
        source: source,
        category: categoryValue.isEmpty ? 'legacy' : categoryValue,
        subtype: subtypeValue.isEmpty ? 'legacy' : subtypeValue,
      );
    }
    return _specs['$source:$categoryValue:$subtypeValue'] ??
        NotificationSubtypeSpec(
          source: source,
          category: categoryValue,
          subtype: subtypeValue,
        );
  }
}

void registerBuiltinNotificationSubtypes() {
  notificationSubtypeSink.registerSubtypes([
    const NotificationSubtypeSpec(
      source: 'global_broadcast',
      category: 'system',
      subtype: 'welcome',
      allowedScreens: {'example_module', 'notifications'},
      modalPriority: 10,
    ),
    const NotificationSubtypeSpec(
      source: 'example_module',
      category: 'demo',
      subtype: 'example_navigate_demo',
      allowedScreens: {'notifications', 'home'},
      modalPriority: 50,
    ),
    const NotificationSubtypeSpec(
      source: 'example_module',
      category: 'demo',
      subtype: 'example_reply_demo',
      modalPriority: 60,
    ),
    const NotificationSubtypeSpec(
      source: 'example_module',
      category: 'record',
      subtype: 'example_record_saved',
      modalPriority: 200,
        ),
  ]);
}
