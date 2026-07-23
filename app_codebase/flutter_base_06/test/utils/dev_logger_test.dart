import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/utils/dev_logger_io.dart';

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
      expect(isDutchDevLogTruthy('YES'), isTrue);
    });
  });

  test('customlog uses debugPrint when enabled', () {
    final lines = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      lines.add(message ?? '');
    };
    addTearDown(() {
      debugPrint = debugPrintThrottled;
    });

    if (!isDutchDevLogTruthy(const String.fromEnvironment('DUTCH_DEV_LOG'))) {
      customlog('should not print');
      expect(lines, isEmpty);
      return;
    }

    customlog('hello');
    expect(lines, ['[dev] hello']);
  });
}
