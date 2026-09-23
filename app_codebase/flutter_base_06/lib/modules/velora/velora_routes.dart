import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'screens/arcori_detail_screen.dart';
import 'screens/velora_screen.dart';
import 'screens/velora_series_screen.dart';
import 'screens/velora_theme_screen.dart';

void registerVeloraRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(slug: 'velora', path: AppPaths.velora),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.velora,
      name: 'velora',
      builder: (context, state) => const VeloraScreen(),
    ),
    GoRoute(
      path: AppPaths.veloraSeries,
      name: 'velora-series',
      builder: (context, state) {
        final key = state.uri.queryParameters['key'] ?? '';
        final name = state.uri.queryParameters['name'];
        return VeloraSeriesScreen(seriesKey: key, seriesName: name);
      },
    ),
    GoRoute(
      path: AppPaths.veloraTheme,
      name: 'velora-theme',
      builder: (context, state) {
        final code = state.uri.queryParameters['code'] ?? '';
        final name = state.uri.queryParameters['name'];
        final series = state.uri.queryParameters['series'] ?? '';
        final seriesName = state.uri.queryParameters['seriesName'];
        return VeloraThemeScreen(
          themeCode: code,
          themeName: name,
          seriesKey: series,
          seriesName: seriesName,
        );
      },
    ),
    GoRoute(
      path: AppPaths.arcoriDetail,
      name: 'arcori-detail',
      builder: (context, state) {
        final id = state.uri.queryParameters['id'] ?? '';
        return ArcoriDetailScreen(internalId: id);
      },
    ),
  ]);
}
