import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'screens/museum_screen.dart';

void registerMuseumRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(
      slug: 'museum',
      path: AppPaths.museum,
    ),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.museum,
      name: 'museum',
      builder: (context, state) => const MuseumScreen(),
    ),
  ]);
}
