import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'screens/kin_customize_screen.dart';
import 'screens/kin_list_screen.dart';
import 'screens/kin_types_screen.dart';

void registerKinRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(slug: 'kin', path: AppPaths.kinTypes),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.kinTypes,
      name: 'kin-types',
      builder: (context, state) => const KinTypesScreen(),
    ),
    GoRoute(
      path: AppPaths.kinList,
      name: 'kin-list',
      builder: (context, state) {
        final typeSerial = state.uri.queryParameters['type'] ?? '';
        return KinListScreen(typeSerial: typeSerial);
      },
    ),
    GoRoute(
      path: AppPaths.kinCustomize,
      name: 'kin-customize',
      builder: (context, state) {
        final kinSerial = state.uri.queryParameters['kin'] ?? '';
        return KinCustomizeScreen(kinSerial: kinSerial);
      },
    ),
  ]);
}
