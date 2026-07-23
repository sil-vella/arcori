import '../navigation/app_paths.dart';
import '../state/auth/auth_state.dart';

/// Option A — protect realtime WS routes only; home/sample/example stay public.
String? redirectForAuth(Uri uri, AuthState auth) {
  if (auth.isBootstrapping) return null;

  final location = uri.path;

  if (AppPaths.requiresAuth(location) && !auth.isAuthenticated) {
    return Uri(
      path: AppPaths.account,
      queryParameters: {
        'from': location,
        'tab': 'sign-in',
      },
    ).toString();
  }

  return null;
}
