import 'dart:io';

import 'package:test/test.dart';

import '../bin/utils/dev_logger.dart';

void main() {
  group('isDutchDevLogTruthy', () {
    test('off for empty and zero', () {
      expect(isDutchDevLogTruthy(null), isFalse);
      expect(isDutchDevLogTruthy(''), isFalse);
      expect(isDutchDevLogTruthy('0'), isFalse);
    });

    test('on for 1, true, yes', () {
      expect(isDutchDevLogTruthy('1'), isTrue);
      expect(isDutchDevLogTruthy('true'), isTrue);
      expect(isDutchDevLogTruthy('TRUE'), isTrue);
      expect(isDutchDevLogTruthy('yes'), isTrue);
    });
  });

  test('customlog silent when DUTCH_DEV_LOG unset', () {
    final saved = Platform.environment['DUTCH_DEV_LOG'];
  // Platform.environment is immutable; smoke-test no-throw when off.
    if (saved != null && isDutchDevLogTruthy(saved)) {
      return;
    }
    expect(() => customlog('noop'), returnsNormally);
  });
}
