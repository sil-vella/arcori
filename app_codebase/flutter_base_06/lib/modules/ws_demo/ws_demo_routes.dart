import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'ws_demo_screen.dart';

void registerWsDemoRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(slug: 'ws_demo', path: AppPaths.wsDemo),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.wsDemo,
      name: 'ws-demo',
      builder: (context, state) => const WsDemoScreen(),
    ),
  ]);
}
