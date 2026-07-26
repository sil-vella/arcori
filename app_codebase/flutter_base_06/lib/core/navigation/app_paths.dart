/// Central path constants for routes, drawer destinations, and navigation.
abstract final class AppPaths {
  static const home = '/';
  static const sample = '/sample';
  static const account = '/account';
  /// Legacy paths — redirect to [account] with tab query.
  static const login = '/login';
  static const register = '/register';
  /// Android/iOS App Link path (not a Flutter web UI).
  static const verifyEmail = '/arcori-verify-email';
  static const wsDemo = '/ws-demo';
  static const exampleModule = '/example-module';
  static const notifications = '/notifications';
  static const velora = '/velora';
  static const veloraTheme = '/velora/theme';
  static const arcoriDetail = '/velora/arcori';
  static const avari = '/avari';

  static const _protectedPaths = {wsDemo};

  /// Only realtime / WS routes require a session. Module screens and bottom
  /// nav are not gated on login — individual actions may use [visibleWhen].
  static bool requiresAuth(String location) {
    final path = location.split('?').first;
    return _protectedPaths.contains(path);
  }
}
