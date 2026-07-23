import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'home_screen.dart';

void registerHomeRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(slug: 'home', path: AppPaths.home),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.home,
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
  ]);
}
