import 'package:arcori/modules/match/input/slam_motion_capability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('slamTurnHints', () {
    test('includes shake when motion is available', () {
      final hints = slamTurnHints(shakeAvailable: true);
      expect(hints.primary, contains('shake'));
      expect(hints.secondary, contains('shake'));
    });

    test('swipe only when motion is unavailable', () {
      final hints = slamTurnHints(shakeAvailable: false);
      expect(hints.primary, contains('swipe down'));
      expect(hints.primary, isNot(contains('shake')));
      expect(hints.secondary, isNot(contains('shake')));
    });
  });
}
