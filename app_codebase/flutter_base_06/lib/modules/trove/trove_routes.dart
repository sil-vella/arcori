import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'screens/trove_screen.dart';

void registerTroveRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(slug: 'trove', path: AppPaths.trove),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.trove,
      name: 'trove',
      builder: (context, state) => const TroveScreen(),
    ),
  ]);
}
