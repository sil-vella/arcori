import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../../firebase_options.dart';
import '../config/app_config.dart';

/// Compile-time Firebase / GA4 switches from dart-define (.env.dart.defines.*).
class FirebaseRuntimeConfig {
  FirebaseRuntimeConfig._();

  static const _switchRaw = String.fromEnvironment('FIREBASE_SWITCH');
  static const _appEnvironmentRaw =
      String.fromEnvironment('FIREBASE_APP_ENVIRONMENT', defaultValue: 'development');

  /// Master on/off for Firebase init and all analytics calls.
  static bool get isEnabled => isEnvTruthy(_switchRaw);

  /// Tagged on every GA4 event as `app_environment`.
  static String get appEnvironment => _appEnvironmentRaw.trim().isEmpty
      ? 'development'
      : _appEnvironmentRaw.trim();

  static bool get isProductionAnalyticsEnvironment {
    final env = appEnvironment.toLowerCase();
    return env == 'production' || env == 'prod';
  }

  /// When true, events include `debug_mode: 1` for GA4 DebugView.
  static bool get includeAnalyticsDebugParameter =>
      !isProductionAnalyticsEnvironment;

  /// Sent as `app_platform` on every GA4 event.
  static String get appPlatform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  /// Non-empty dart-defines for the current platform.
  static bool get isCurrentPlatformConfigured =>
      DefaultFirebaseOptions.isCurrentPlatformConfigured;
}
