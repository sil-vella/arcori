import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'screens/fragment_store_screen.dart';

void registerStoreRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(
      slug: 'fragment-store',
      path: AppPaths.fragmentStore,
    ),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.fragmentStore,
      name: 'fragment-store',
      builder: (context, state) => const FragmentStoreScreen(),
    ),
  ]);
}
