import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/config/app_config.dart';

void main() {
  group('isEnvTruthy', () {
    test('truthy values', () {
      expect(isEnvTruthy('1'), isTrue);
      expect(isEnvTruthy('true'), isTrue);
      expect(isEnvTruthy('YES'), isTrue);
    });

    test('falsy values', () {
      expect(isEnvTruthy('0'), isFalse);
      expect(isEnvTruthy('false'), isFalse);
      expect(isEnvTruthy(''), isFalse);
      expect(isEnvTruthy(null), isFalse);
    });
  });

  test('showIntroLottie follows compile-time define', () {
    if (!isEnvTruthy(const String.fromEnvironment('SHOW_INTRO_LOTTIE'))) {
      expect(AppConfig.showIntroLottie, isFalse);
    }
  });
}
