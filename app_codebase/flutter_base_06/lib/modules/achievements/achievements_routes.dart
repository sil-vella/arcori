import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'screens/achievements_screen.dart';

void registerAchievementsRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(
      slug: 'achievements',
      path: AppPaths.achievements,
    ),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.achievements,
      name: 'achievements',
      builder: (context, state) => const AchievementsScreen(),
    ),
  ]);
}
