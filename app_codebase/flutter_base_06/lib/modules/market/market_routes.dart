import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'screens/market_screen.dart';

void registerMarketRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(slug: 'market', path: AppPaths.market),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.market,
      name: 'market',
      builder: (context, state) => const MarketScreen(),
    ),
  ]);
}
