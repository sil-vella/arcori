import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'screens/avari_profile_screen.dart';

void registerAvariRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(slug: 'avari', path: AppPaths.avari),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.avari,
      name: 'avari',
      builder: (context, state) => const AvariProfileScreen(),
    ),
  ]);
}
