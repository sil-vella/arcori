import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/analytics/analytics_service.dart';
import 'package:arcori/core/analytics/firebase_runtime_config.dart';
import 'package:arcori/core/config/app_config.dart';

void main() {
  group('FirebaseRuntimeConfig', () {
    test('isEnabled follows compile-time FIREBASE_SWITCH', () {
      if (isEnvTruthy(const String.fromEnvironment('FIREBASE_SWITCH'))) {
        expect(FirebaseRuntimeConfig.isEnabled, isTrue);
      } else {
        expect(FirebaseRuntimeConfig.isEnabled, isFalse);
      }
    });

    test('appEnvironment defaults to development when unset', () {
      const raw = String.fromEnvironment('FIREBASE_APP_ENVIRONMENT');
      if (raw.trim().isEmpty) {
        expect(FirebaseRuntimeConfig.appEnvironment, 'development');
      }
    });

    test('isProductionAnalyticsEnvironment for prod values', () {
      const raw = String.fromEnvironment('FIREBASE_APP_ENVIRONMENT');
      final env = raw.trim().toLowerCase();
      if (env == 'production' || env == 'prod') {
        expect(FirebaseRuntimeConfig.isProductionAnalyticsEnvironment, isTrue);
        expect(FirebaseRuntimeConfig.includeAnalyticsDebugParameter, isFalse);
      }
    });
  });

  group('AnalyticsService', () {
    test('logPlatformAppLoad does not throw when Firebase is disabled', () async {
      if (FirebaseRuntimeConfig.isEnabled) return;
      await expectLater(
        AnalyticsService.instance.logPlatformAppLoad(),
        completes,
      );
    });

    test('logEvent does not throw when Firebase is disabled', () async {
      if (FirebaseRuntimeConfig.isEnabled) return;
      await expectLater(
        AnalyticsService.instance.logEvent('test_event'),
        completes,
      );
    });
  });
}
