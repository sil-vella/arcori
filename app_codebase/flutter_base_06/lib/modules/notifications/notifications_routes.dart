import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'notifications_screen.dart';

void registerNotificationsRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(
      slug: 'notifications',
      path: AppPaths.notifications,
    ),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.notifications,
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
  ]);
}
