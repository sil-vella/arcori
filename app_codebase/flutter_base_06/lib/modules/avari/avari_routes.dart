import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'circulating_browse.dart';
import 'screens/avari_profile_screen.dart';
import 'screens/canister_open_screen.dart';
import 'screens/circulating_arcori_screen.dart';

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
    GoRoute(
      path: AppPaths.avariCirculating,
      name: 'avari-circulating',
      builder: (context, state) => const CirculatingArcoriScreen(),
    ),
    GoRoute(
      path: AppPaths.avariCanister,
      name: 'avari-canister',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is CirculatingCanister) {
          return CanisterOpenScreen(canister: extra);
        }
        return const CanisterOpenMissing();
      },
    ),
  ]);
}
