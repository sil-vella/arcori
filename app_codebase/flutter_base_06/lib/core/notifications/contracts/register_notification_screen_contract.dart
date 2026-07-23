/// Let feature modules register navigable screens for notification `data.response`
/// navigate buttons without depending on the registry implementation.
///
/// Wired from [registerApplicationModules] in `modules/module_registry.dart`.
/// JSON uses [NotificationNavigableScreen.slug] as `"screen": "…"`; [path] must
/// match [GoRoute.path] (typically [AppPaths]).
library;

/// Logical screen id for notification JSON (`"screen": slug`).
class NotificationNavigableScreen {
  const NotificationNavigableScreen({
    required this.slug,
    required this.path,
  });

  final String slug;
  final String path;
}

abstract interface class NotificationScreenSink {
  void registerScreens(List<NotificationNavigableScreen> screens);
}
