import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'account_screen.dart';
import 'email_verify_deep_link.dart';

void registerAuthRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(slug: 'account', path: AppPaths.account),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.account,
      name: 'account',
      builder: (context, state) {
        final tab = accountTabFromQuery(state.uri.queryParameters['tab']);
        return AccountScreen(initialTab: tab);
      },
    ),
    GoRoute(
      path: AppPaths.verifyEmail,
      redirect: (context, state) {
        final token = state.uri.queryParameters['token']?.trim() ?? '';
        if (token.isNotEmpty) {
          EmailVerifyDeepLinkHandler.onToken(token);
        }
        return AppPaths.account;
      },
    ),
    GoRoute(
      path: AppPaths.login,
      redirect: (context, state) {
        final from = state.uri.queryParameters['from'];
        final params = <String, String>{'tab': 'sign-in'};
        if (from != null && from.isNotEmpty) params['from'] = from;
        return Uri(path: AppPaths.account, queryParameters: params).toString();
      },
    ),
    GoRoute(
      path: AppPaths.register,
      redirect: (_, __) =>
          Uri(path: AppPaths.account, queryParameters: {'tab': 'create'})
              .toString(),
    ),
  ]);
}
