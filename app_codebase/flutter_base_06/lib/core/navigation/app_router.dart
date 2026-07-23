import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth/auth_providers.dart';
import '../../modules/auth/email_verify_deep_link.dart';
import 'app_paths.dart';
import 'app_shell.dart';
import 'auth_redirect.dart';
import 'contracts/register_route_contract.dart';

/// Builds a router from the current sink contents, with auth redirect (Option A).
GoRouter buildAppGoRouter(Ref ref) {
  final routes = List<RouteBase>.of(_AppRouteRegistry._instance._routes);
  final router = GoRouter(
    initialLocation: AppPaths.home,
    redirect: (context, state) {
      final uri = state.uri;
      // Custom scheme: arcori://wf-template-verify-email?token=…
      if (uri.scheme == 'arcori') {
        final token = EmailVerifyDeepLinkHandler.tokenFromUri(uri);
        if (token != null) {
          EmailVerifyDeepLinkHandler.onToken(token);
        }
        return AppPaths.account;
      }
      final auth = ref.read(authProvider);
      return redirectForAuth(uri, auth);
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: routes,
      ),
    ],
  );

  ref.listen(authProvider, (_, __) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return buildAppGoRouter(ref);
});

void resetAppRouteRegistry() => _AppRouteRegistry._instance.clear();

final AppRouteSink appRouteSink = _AppRouteRegistry._instance;

class _AppRouteRegistry implements AppRouteSink {
  _AppRouteRegistry._();

  static final _AppRouteRegistry _instance = _AppRouteRegistry._();

  final List<RouteBase> _routes = [];

  void clear() => _routes.clear();

  @override
  void addRoutes(List<RouteBase> routes) => _routes.addAll(routes);
}
