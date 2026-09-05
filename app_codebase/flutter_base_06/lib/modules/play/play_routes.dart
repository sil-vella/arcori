import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'screens/game_controls_screen.dart';
import 'screens/play_screen.dart';

void registerPlayRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(slug: 'play', path: AppPaths.play),
    const NotificationNavigableScreen(
      slug: 'game-controls',
      path: AppPaths.gameControls,
    ),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.play,
      name: 'play',
      builder: (context, state) => const PlayScreen(),
    ),
    GoRoute(
      path: AppPaths.gameControls,
      name: 'game-controls',
      builder: (context, state) => const GameControlsScreen(),
    ),
  ]);
}
