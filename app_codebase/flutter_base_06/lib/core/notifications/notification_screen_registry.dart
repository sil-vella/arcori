/// Collects notification navigable screens from modules; [resolveNotificationScreenPath]
/// is used by the response executor at runtime.
library;

import 'contracts/register_notification_screen_contract.dart';

final NotificationScreenSink notificationScreenSink =
    _NotificationScreenRegistry._instance;

void resetNotificationScreenRegistry() =>
    _NotificationScreenRegistry._instance.clear();

String? resolveNotificationScreenPath(String slug) {
  return _NotificationScreenRegistry._instance._screenPaths[slug.trim()];
}

Set<String> registeredNotificationScreenSlugs() =>
    Set.unmodifiable(_NotificationScreenRegistry._instance._screenPaths.keys);

class _NotificationScreenRegistry implements NotificationScreenSink {
  _NotificationScreenRegistry._();

  static final _NotificationScreenRegistry _instance =
      _NotificationScreenRegistry._();

  final Map<String, String> _screenPaths = {};

  void clear() => _screenPaths.clear();

  @override
  void registerScreens(List<NotificationNavigableScreen> screens) {
    for (final screen in screens) {
      final key = screen.slug.trim();
      final route = screen.path.trim();
      if (key.isEmpty || route.isEmpty) {
        continue;
      }
      _screenPaths[key] = route;
    }
  }
}
