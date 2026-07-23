import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'sample_screen.dart';

void registerSampleRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(slug: 'sample', path: AppPaths.sample),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.sample,
      name: 'sample',
      builder: (context, state) => const SampleScreen(),
    ),
  ]);
}
