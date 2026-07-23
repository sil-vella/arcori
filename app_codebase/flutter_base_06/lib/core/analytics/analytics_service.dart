import 'package:firebase_analytics/firebase_analytics.dart';

import '../../utils/dev_logger.dart';
import 'firebase_runtime_config.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// GA4 wrapper; all calls no-op when [FirebaseRuntimeConfig.isEnabled] is false.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  /// Logs a custom GA4 event with standard template parameters merged in.
  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!FirebaseRuntimeConfig.isEnabled) return;
    try {
      final merged = <String, Object>{
        'app_environment': FirebaseRuntimeConfig.appEnvironment,
        'app_platform': FirebaseRuntimeConfig.appPlatform,
        ...?parameters,
      };
      if (FirebaseRuntimeConfig.includeAnalyticsDebugParameter) {
        merged['debug_mode'] = 1;
      }
      await _analytics.logEvent(name: name, parameters: merged);
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('AnalyticsService.logEvent($name) failed: $e');
      }
    }
  }

  /// Platform bootstrap event on cold start (Android or iOS only).
  Future<void> logPlatformAppLoad() async {
    switch (FirebaseRuntimeConfig.appPlatform) {
      case 'android':
        await logEvent('app_load_android');
      case 'ios':
        await logEvent('app_load_ios');
      default:
        break;
    }
  }
}
