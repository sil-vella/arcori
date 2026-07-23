import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'example_module_screen.dart';

void registerExampleModuleRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(
      slug: 'example_module',
      path: AppPaths.exampleModule,
    ),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.exampleModule,
      name: 'example-module',
      builder: (context, state) => const ExampleModuleScreen(),
    ),
  ]);
}
